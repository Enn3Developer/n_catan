package main

import (
	"crypto/rand"
	"encoding/hex"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"time"
)

type Journal struct {
	Backup     string          `json:"backup"`
	Files      []string        `json:"files"`
	OldPresent map[string]bool `json:"old_present"`
}

func copyFile(from, to string, mode os.FileMode) error {
	src, e := os.Open(from)
	if e != nil {
		return e
	}
	defer src.Close()
	dst, e := os.OpenFile(to, os.O_CREATE|os.O_EXCL|os.O_WRONLY, mode)
	if e != nil {
		return e
	}
	_, e = io.Copy(dst, src)
	if e == nil {
		e = dst.Sync()
	}
	ce := dst.Close()
	if e != nil {
		return e
	}
	return ce
}
func renameRetry(from, to string) error {
	var e error
	for i := 0; i < 30; i++ {
		if e = os.Rename(from, to); e == nil {
			return nil
		}
		time.Sleep(100 * time.Millisecond)
	}
	return e
}
func waitForExit(pid int) error {
	if pid <= 0 {
		return nil
	}
	deadline := time.Now().Add(90 * time.Second)
	for processAlive(pid) {
		if time.Now().After(deadline) {
			return errors.New("game is still running; update was not installed")
		}
		time.Sleep(150 * time.Millisecond)
	}
	return nil
}
func journalPath(install string) string { return filepath.Join(install, ".n-catan-update.json") }
func validateJournal(install string, j Journal) error {
	if filepath.Dir(j.Backup) != install || !strings.HasPrefix(filepath.Base(j.Backup), ".n-catan-backup-") {
		return errors.New("invalid recovery path")
	}
	game, helper, e := platformNames(platformID())
	if e != nil {
		return e
	}
	if len(j.Files) != 2 || j.Files[0] != game || j.Files[1] != helper {
		return errors.New("invalid recovery files")
	}
	return nil
}
func rollback(install string, j Journal) error {
	if e := validateJournal(install, j); e != nil {
		return e
	}
	for _, name := range j.Files {
		backup := filepath.Join(j.Backup, name)
		target := filepath.Join(install, name)
		if _, e := os.Lstat(backup); e == nil {
			if e = os.Remove(target); e != nil && !os.IsNotExist(e) {
				return e
			}
			if e = renameRetry(backup, target); e != nil {
				return e
			}
		} else if !os.IsNotExist(e) {
			return e
		} else if !j.OldPresent[name] {
			if e = os.Remove(target); e != nil && !os.IsNotExist(e) {
				return e
			}
		}
	}
	return os.Remove(journalPath(install))
}
func recoverInstall(install string) error {
	raw, e := os.ReadFile(journalPath(install))
	if os.IsNotExist(e) {
		return nil
	}
	if e != nil {
		return e
	}
	var j Journal
	if e = json.Unmarshal(raw, &j); e != nil {
		return e
	}
	return rollback(install, j)
}
func (a *App) apply(pid int, restart bool) error {
	a.report("installing", "Waiting for the game to close…")
	if e := waitForExit(pid); e != nil {
		return e
	}
	if e := recoverInstall(a.Install); e != nil {
		return fmt.Errorf("recover previous update: %w", e)
	}
	m, p, e := a.cachedManifest()
	if e != nil {
		return e
	}
	ready := filepath.Join(a.Cache, "ready")
	for _, f := range []FileSpec{p.Game, p.Updater} {
		if e = verifyFile(filepath.Join(ready, f.Name), f); e != nil {
			return e
		}
	}
	stage, e := os.MkdirTemp(a.Install, ".n-catan-stage-")
	if e != nil {
		return errors.New("installation folder is not writable; move the game to your own folder")
	}
	defer os.RemoveAll(stage)
	for _, f := range []FileSpec{p.Game, p.Updater} {
		if e = copyFile(filepath.Join(ready, f.Name), filepath.Join(stage, f.Name), 0700); e != nil {
			return e
		}
		if e = verifyFile(filepath.Join(stage, f.Name), f); e != nil {
			return e
		}
	}
	backup, e := os.MkdirTemp(a.Install, ".n-catan-backup-")
	if e != nil {
		return e
	}
	j := Journal{Backup: backup, Files: []string{p.Game.Name, p.Updater.Name}, OldPresent: map[string]bool{}}
	for _, name := range j.Files {
		st, se := os.Lstat(filepath.Join(a.Install, name))
		if se != nil && !os.IsNotExist(se) {
			return se
		}
		if se == nil {
			if !st.Mode().IsRegular() {
				return errors.New("refusing to replace a symlink or non-file")
			}
			j.OldPresent[name] = true
		}
	}
	if !j.OldPresent[p.Game.Name] {
		return errors.New("game executable is missing")
	}
	if e = writeJSON(journalPath(a.Install), j); e != nil {
		return e
	}
	installErr := func() error {
		for _, name := range j.Files {
			if j.OldPresent[name] {
				if e = renameRetry(filepath.Join(a.Install, name), filepath.Join(backup, name)); e != nil {
					return e
				}
			}
			if e = renameRetry(filepath.Join(stage, name), filepath.Join(a.Install, name)); e != nil {
				return e
			}
		}
		if restart {
			return startAndCheck(a.Install, p.Game.Name)
		}
		return nil
	}()
	if installErr != nil {
		if re := rollback(a.Install, j); re != nil {
			return fmt.Errorf("install failed (%v); run the updater to recover: %w", installErr, re)
		}
		if restart {
			_ = exec.Command(filepath.Join(a.Install, p.Game.Name)).Start()
		}
		return fmt.Errorf("update failed; previous version restored: %w", installErr)
	}
	// Commit the transaction only after the new game reports a healthy startup.
	if e = os.Remove(journalPath(a.Install)); e != nil {
		return e
	}
	oldRecord := filepath.Join(a.Install, ".n-catan-previous.json")
	if raw, re := os.ReadFile(oldRecord); re == nil {
		var old Journal
		if json.Unmarshal(raw, &old) == nil && validateJournal(a.Install, old) == nil && old.Backup != backup {
			_ = os.RemoveAll(old.Backup)
		}
	}
	_ = writeJSON(oldRecord, j)
	a.Status.Version = m.Version
	a.Status.Protocol = m.Protocol
	a.report("installed", "Updated to "+m.Version+". Previous version retained for recovery.")
	_ = os.RemoveAll(ready)
	_ = os.Remove(filepath.Join(a.Cache, "download.zip"))
	return nil
}
func startAndCheck(install, game string) error {
	var nonce [16]byte
	if _, e := rand.Read(nonce[:]); e != nil {
		return e
	}
	token := hex.EncodeToString(nonce[:])
	marker := filepath.Join(install, ".n-catan-health-"+token)
	defer os.Remove(marker)
	command := exec.Command(filepath.Join(install, game), "--", "--update-health="+token)
	command.Dir = install
	if e := command.Start(); e != nil {
		return e
	}
	exited := make(chan error, 1)
	go func() { exited <- command.Wait() }()
	deadline := time.NewTimer(90 * time.Second)
	defer deadline.Stop()
	tick := time.NewTicker(200 * time.Millisecond)
	defer tick.Stop()
	for {
		select {
		case <-tick.C:
			if raw, e := os.ReadFile(marker); e == nil && string(raw) == token {
				return nil
			}
		case e := <-exited:
			return fmt.Errorf("new game exited before startup completed: %v", e)
		case <-deadline.C:
			_ = command.Process.Kill()
			<-exited
			return errors.New("new game did not finish startup")
		}
	}
}
func launch(install string) error {
	game, helper, e := platformNames(platformID())
	if e != nil {
		return e
	}
	if _, e = os.Stat(journalPath(install)); e == nil {
		// Recovery may replace the installed updater on Windows: run a temporary copy.
		temp, e := os.MkdirTemp("", "n-catan-recovery-")
		if e != nil {
			return e
		}
		self, e := os.Executable()
		if e != nil {
			return e
		}
		runner := filepath.Join(temp, helper)
		if e = copyFile(self, runner, 0700); e != nil {
			return e
		}
		return exec.Command(runner, "--mode", "recover", "--install-dir", install, "--wait-pid", fmt.Sprint(os.Getpid())).Start()
	}
	command := exec.Command(filepath.Join(install, game))
	command.Dir = install
	return command.Start()
}
