package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"strings"
	"time"
)

type Status struct {
	State    string `json:"state"`
	Message  string `json:"message"`
	Version  string `json:"version,omitempty"`
	Protocol int    `json:"protocol,omitempty"`
	Kind     string `json:"kind,omitempty"`
	Bytes    int64  `json:"bytes,omitempty"`
	Total    int64  `json:"total,omitempty"`
}
type App struct {
	Cache, Install, CurrentVersion, Platform string
	Status                                   Status
	Client                                   *http.Client
}

func httpClient() *http.Client {
	return &http.Client{Timeout: 30 * time.Minute, CheckRedirect: func(req *http.Request, via []*http.Request) error {
		if len(via) > 8 {
			return errors.New("too many redirects")
		}
		host := req.URL.Hostname()
		if req.URL.Scheme != "https" || req.URL.User != nil || req.URL.Port() != "" || !(host == "github.com" || strings.HasSuffix(host, ".githubusercontent.com")) {
			return errors.New("untrusted update redirect")
		}
		return nil
	}}
}
func writeJSON(path string, v any) error {
	b, e := json.Marshal(v)
	if e != nil {
		return e
	}
	return atomicWrite(path, b, 0600)
}
func atomicWrite(path string, b []byte, mode os.FileMode) error {
	f, e := os.CreateTemp(filepath.Dir(path), ".write-*")
	if e != nil {
		return e
	}
	name := f.Name()
	defer os.Remove(name)
	if e = f.Chmod(mode); e == nil {
		_, e = f.Write(b)
	}
	if e == nil {
		e = f.Sync()
	}
	ce := f.Close()
	if e != nil {
		return e
	}
	if ce != nil {
		return ce
	}
	return os.Rename(name, path)
}
func (a *App) report(state, message string) {
	a.Status.State = state
	a.Status.Message = message
	_ = writeJSON(filepath.Join(a.Cache, "status.json"), a.Status)
}
func (a *App) get(ctx context.Context, address string) (*http.Response, error) {
	u, e := url.Parse(address)
	if e != nil || u.Scheme != "https" || u.Host != "github.com" || u.User != nil {
		return nil, errors.New("invalid update URL")
	}
	req, e := http.NewRequestWithContext(ctx, "GET", address, nil)
	if e != nil {
		return nil, e
	}
	req.Header.Set("User-Agent", "n-catan-updater/1")
	req.Header.Set("Accept", "application/octet-stream")
	return a.Client.Do(req)
}
func (a *App) cachedManifest() (Manifest, Platform, error) {
	raw, e := os.ReadFile(filepath.Join(a.Cache, "manifest.json"))
	if e != nil {
		return Manifest{}, Platform{}, e
	}
	m, e := readManifest(raw, publicPEM)
	if e != nil {
		return m, Platform{}, e
	}
	p, ok := m.Platforms[a.Platform]
	if !ok {
		return m, p, errors.New("no update for this platform")
	}
	comparison, e := compareVersions(m.Version, a.CurrentVersion)
	if e != nil {
		return m, p, e
	}
	if comparison <= 0 {
		return m, p, errors.New("refusing a same-version or older update")
	}
	return m, p, nil
}
func (a *App) check(ctx context.Context) error {
	a.report("checking", "Checking for updates…")
	resp, e := a.get(ctx, manifestURL)
	if e != nil {
		return e
	}
	defer resp.Body.Close()
	if resp.StatusCode == 404 {
		a.report("current", "No published update is available yet.")
		return nil
	}
	if resp.StatusCode != 200 {
		return fmt.Errorf("update check returned HTTP %d; try again later", resp.StatusCode)
	}
	raw, e := io.ReadAll(io.LimitReader(resp.Body, maxManifest+1))
	if e != nil {
		return e
	}
	m, e := readManifest(raw, publicPEM)
	if e != nil {
		return e
	}
	c, e := compareVersions(m.Version, a.CurrentVersion)
	if e != nil {
		return e
	}
	a.Status.Version = m.Version
	a.Status.Protocol = m.Protocol
	if c <= 0 {
		a.report("current", "You are up to date.")
		return nil
	}
	p, ok := m.Platforms[a.Platform]
	if !ok {
		return errors.New("this release does not support this platform")
	}
	if e = atomicWrite(filepath.Join(a.Cache, "manifest.json"), raw, 0600); e != nil {
		return e
	}
	a.Status.Kind = "full"
	a.Status.Total = p.Full.Size
	if d := chooseDelta(p, a.Install); d != nil {
		a.Status.Kind = "delta"
		a.Status.Total = d.Asset.Size
	}
	a.report("available", "Version "+m.Version+" is available.")
	return nil
}
func (a *App) downloadFile(ctx context.Context, m Manifest, spec FileSpec, path string) error {
	if verifyFile(path, spec) == nil {
		a.Status.Bytes = spec.Size
		a.report("downloading", "Using verified cached download.")
		return nil
	}
	_ = os.Remove(path)
	resp, e := a.get(ctx, assetURL(m.Version, spec.Name))
	if e != nil {
		return e
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return fmt.Errorf("download returned HTTP %d", resp.StatusCode)
	}
	if resp.ContentLength > 0 && resp.ContentLength != spec.Size {
		return errors.New("unexpected download length")
	}
	f, e := os.OpenFile(path, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0600)
	if e != nil {
		return e
	}
	a.Status.Bytes = 0
	a.Status.Total = spec.Size
	last := time.Time{}
	buf := make([]byte, 256<<10)
	for {
		n, re := resp.Body.Read(buf)
		if n > 0 {
			if int64(n) > spec.Size-a.Status.Bytes {
				f.Close()
				return errors.New("download size exceeded")
			}
			if _, e = f.Write(buf[:n]); e != nil {
				f.Close()
				return e
			}
			a.Status.Bytes += int64(n)
			if time.Since(last) > 200*time.Millisecond {
				a.report("downloading", "Downloading "+a.Status.Kind+" update…")
				last = time.Now()
			}
		}
		if re == io.EOF {
			break
		}
		if re != nil {
			f.Close()
			return re
		}
	}
	if e = f.Sync(); e != nil {
		f.Close()
		return e
	}
	if e = f.Close(); e != nil {
		return e
	}
	return verifyFile(path, spec)
}
func (a *App) download(ctx context.Context) error {
	m, p, e := a.cachedManifest()
	if e != nil {
		return e
	}
	a.Status.Version = m.Version
	a.Status.Protocol = m.Protocol
	// Prepare only inside our cache. The running game is never changed here.
	ready := filepath.Join(a.Cache, "ready")
	if e = os.RemoveAll(ready); e != nil {
		return e
	}
	d := chooseDelta(p, a.Install)
	for attempt := 0; attempt < 2; attempt++ {
		spec := p.Full
		a.Status.Kind = "full"
		if d != nil {
			spec = d.Asset
			a.Status.Kind = "delta"
		}
		archive := filepath.Join(a.Cache, "download.zip")
		a.report("downloading", "Downloading "+a.Status.Kind+" update…")
		e = a.downloadFile(ctx, m, spec, archive)
		if e == nil {
			a.report("preparing", "Verifying and preparing update…")
			e = stageArchive(archive, ready, a.Install, p, d)
		}
		if e == nil {
			a.report("ready", "Update verified. Restart from the main menu to install.")
			return nil
		}
		_ = os.RemoveAll(ready)
		if d == nil {
			return e
		}
		d = nil
		a.report("downloading", "Delta unavailable or invalid; downloading the full update.")
	}
	return errors.New("could not prepare update")
}
