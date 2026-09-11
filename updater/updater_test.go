package main

import (
	"archive/zip"
	"bytes"
	"context"
	"crypto"
	"crypto/rand"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"io"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"runtime"
	"strings"
	"sync"
	"testing"
)

var once sync.Once
var testKey *rsa.PrivateKey

func signed(t *testing.T, m Manifest) []byte {
	t.Helper()
	once.Do(func() { testKey, _ = rsa.GenerateKey(rand.Reader, 2048) })
	raw, _ := json.Marshal(m)
	h := sha256.Sum256(raw)
	sig, e := rsa.SignPKCS1v15(rand.Reader, testKey, crypto.SHA256, h[:])
	if e != nil {
		t.Fatal(e)
	}
	b, _ := json.Marshal(Envelope{base64.StdEncoding.EncodeToString(raw), base64.StdEncoding.EncodeToString(sig)})
	return b
}
func spec(name string, b []byte) FileSpec {
	h := sha256.Sum256(b)
	return FileSpec{name, int64(len(b)), hex.EncodeToString(h[:])}
}
func zipBytes(t *testing.T, files map[string][]byte) []byte {
	t.Helper()
	var b bytes.Buffer
	z := zip.NewWriter(&b)
	for n, data := range files {
		f, e := z.Create(n)
		if e != nil {
			t.Fatal(e)
		}
		if _, e = f.Write(data); e != nil {
			t.Fatal(e)
		}
	}
	if e := z.Close(); e != nil {
		t.Fatal(e)
	}
	return b.Bytes()
}
func put(t *testing.T, p string, b []byte) {
	t.Helper()
	if e := os.WriteFile(p, b, 0700); e != nil {
		t.Fatal(e)
	}
}
func setup(t *testing.T) (*App, Manifest, Platform) {
	t.Helper()
	game, helper, _ := platformNames(platformID())
	p := Platform{Game: spec(game, []byte("new game")), Updater: spec(helper, []byte("new helper")), Full: spec("full.zip", []byte("placeholder"))}
	m := Manifest{1, "v1.1.0", 9, repository, strings.Repeat("a", 40), map[string]Platform{platformID(): p}}
	b := signed(t, m)
	der, _ := x509.MarshalPKIXPublicKey(&testKey.PublicKey)
	old := publicPEM
	publicPEM = pem.EncodeToMemory(&pem.Block{Type: "PUBLIC KEY", Bytes: der})
	t.Cleanup(func() { publicPEM = old })
	a := &App{Cache: t.TempDir(), Install: t.TempDir(), CurrentVersion: "v1.0.0", Platform: platformID(), Client: httpClient()}
	put(t, filepath.Join(a.Cache, "manifest.json"), b)
	return a, m, p
}
func TestSignaturesAndDowngrades(t *testing.T) {
	a, m, _ := setup(t)
	b := signed(t, m)
	if _, e := readManifest(b, publicPEM); e != nil {
		t.Fatal(e)
	}
	var env Envelope
	json.Unmarshal(b, &env)
	raw, _ := base64.StdEncoding.DecodeString(env.Payload)
	env.Payload = base64.StdEncoding.EncodeToString(bytes.Replace(raw, []byte("v1.1.0"), []byte("v9.9.9"), 1))
	b, _ = json.Marshal(env)
	if _, e := readManifest(b, publicPEM); e == nil {
		t.Fatal("accepted altered signed payload")
	}
	env.Signature = base64.StdEncoding.EncodeToString([]byte("forged"))
	b, _ = json.Marshal(env)
	if _, e := readManifest(b, publicPEM); e == nil {
		t.Fatal("accepted forged signature")
	}
	m.Version = "../../bad"
	if _, e := readManifest(signed(t, m), publicPEM); e == nil {
		t.Fatal("accepted unsafe version")
	}
	m.Version = "v1.0.0"
	put(t, filepath.Join(a.Cache, "manifest.json"), signed(t, m))
	if _, _, e := a.cachedManifest(); e == nil {
		t.Fatal("accepted same version")
	}
}
func TestVersionOrder(t *testing.T) {
	for _, v := range []struct {
		a, b string
		want int
	}{{"v1.0.0", "0.9.9", 1}, {"v1.0.0", "1.0.0", 0}, {"1.0.0-rc.2", "1.0.0-rc.10", -1}, {"1.0.0-rc.1", "1.0.0", -1}, {"2.0.0", "1.99.99", 1}} {
		n, e := compareVersions(v.a, v.b)
		if e != nil || n != v.want {
			t.Fatalf("%+v => %d %v", v, n, e)
		}
	}
}
func TestDeltaBoundsAndBase(t *testing.T) {
	old := []byte("unchanged prefix and old ending")
	target := []byte("unchanged prefix and NEW ending")
	base := filepath.Join(t.TempDir(), "base")
	put(t, base, old)
	offset := int64(0)
	p := DeltaPlan{1, spec("old", old).SHA256, spec("target", target).SHA256, int64(len(target)), []DeltaOp{{&offset, 21}, {nil, int64(len(target) - 21)}}}
	archive := func() *zip.Reader {
		meta, _ := json.Marshal(p)
		b := zipBytes(t, map[string][]byte{"delta.json": meta, "payload.bin": target[21:]})
		z, e := zip.NewReader(bytes.NewReader(b), int64(len(b)))
		if e != nil {
			t.Fatal(e)
		}
		return z
	}
	out := filepath.Join(t.TempDir(), "new")
	if e := reconstruct(archive(), base, out, spec("new", target), p.BaseSHA256); e != nil {
		t.Fatal(e)
	}
	got, _ := os.ReadFile(out)
	if !bytes.Equal(got, target) {
		t.Fatal("wrong output")
	}
	put(t, base, []byte("changed"))
	if e := reconstruct(archive(), base, filepath.Join(t.TempDir(), "bad"), spec("new", target), p.BaseSHA256); e == nil {
		t.Fatal("accepted wrong base")
	}
	put(t, base, old)
	offset = 9999
	if e := reconstruct(archive(), base, filepath.Join(t.TempDir(), "bad"), spec("new", target), p.BaseSHA256); e == nil {
		t.Fatal("accepted out of bounds copy")
	}
}
func TestArchiveTraversalAndTamper(t *testing.T) {
	a, _, p := setup(t)
	put(t, filepath.Join(a.Install, p.Game.Name), []byte("old game"))
	put(t, filepath.Join(a.Install, p.Updater.Name), []byte("old helper"))
	for _, n := range []string{"../escape", "/absolute", "sub/file"} {
		b := zipBytes(t, map[string][]byte{p.Game.Name: []byte("new game"), p.Updater.Name: []byte("new helper"), n: []byte("bad")})
		path := filepath.Join(t.TempDir(), "bad.zip")
		put(t, path, b)
		if e := stageArchive(path, filepath.Join(t.TempDir(), "stage"), a.Install, p, nil); e == nil {
			t.Fatal("accepted unsafe path", n)
		}
	}
	ready := filepath.Join(a.Cache, "ready")
	os.Mkdir(ready, 0700)
	put(t, filepath.Join(ready, p.Game.Name), []byte("new game"))
	put(t, filepath.Join(ready, p.Updater.Name), []byte("tampered"))
	if e := a.apply(0, false); e == nil {
		t.Fatal("installed modified helper")
	}
	got, _ := os.ReadFile(filepath.Join(a.Install, p.Game.Name))
	if string(got) != "old game" {
		t.Fatal("modified current game")
	}
}

type roundTrip func(*http.Request) (*http.Response, error)

func (f roundTrip) RoundTrip(r *http.Request) (*http.Response, error) { return f(r) }
func TestFullFallback(t *testing.T) {
	a, m, p := setup(t)
	old := []byte("old game")
	put(t, filepath.Join(a.Install, p.Game.Name), old)
	body := make([]byte, 4000)
	rand.Read(body)
	p.Game = spec(p.Game.Name, body)
	full := zipBytes(t, map[string][]byte{p.Game.Name: body, p.Updater.Name: []byte("new helper")})
	p.Full = spec("full.zip", full)
	bad := []byte("bad delta")
	p.Deltas = []DeltaSpec{{"v1.0.0", spec("old", old).SHA256, spec("delta.zip", bad)}}
	m.Platforms[a.Platform] = p
	put(t, filepath.Join(a.Cache, "manifest.json"), signed(t, m))
	paths := []string{}
	a.Client = &http.Client{Transport: roundTrip(func(r *http.Request) (*http.Response, error) {
		paths = append(paths, r.URL.Path)
		b := full
		if strings.HasSuffix(r.URL.Path, "delta.zip") {
			b = bad
		}
		return &http.Response{StatusCode: 200, Body: io.NopCloser(bytes.NewReader(b)), ContentLength: int64(len(b)), Header: make(http.Header)}, nil
	})}
	if e := a.download(context.Background()); e != nil {
		t.Fatal(e)
	}
	if len(paths) != 2 || !strings.HasSuffix(paths[0], "delta.zip") || !strings.HasSuffix(paths[1], "full.zip") {
		t.Fatal(paths)
	}
	if a.Status.State != "ready" || verifyFile(filepath.Join(a.Cache, "ready", p.Game.Name), p.Game) != nil {
		t.Fatal("fallback not verified")
	}
}
func TestInstallAndRecovery(t *testing.T) {
	a, _, p := setup(t)
	put(t, filepath.Join(a.Install, p.Game.Name), []byte("old game"))
	put(t, filepath.Join(a.Install, p.Updater.Name), []byte("old helper"))
	ready := filepath.Join(a.Cache, "ready")
	os.Mkdir(ready, 0700)
	put(t, filepath.Join(ready, p.Game.Name), []byte("new game"))
	put(t, filepath.Join(ready, p.Updater.Name), []byte("new helper"))
	if e := a.apply(0, false); e != nil {
		t.Fatal(e)
	}
	if e := verifyFile(filepath.Join(a.Install, p.Game.Name), p.Game); e != nil {
		t.Fatal(e)
	}
	raw, e := os.ReadFile(filepath.Join(a.Install, ".n-catan-previous.json"))
	if e != nil {
		t.Fatal(e)
	}
	var j Journal
	json.Unmarshal(raw, &j)
	old, _ := os.ReadFile(filepath.Join(j.Backup, p.Game.Name))
	if string(old) != "old game" {
		t.Fatal("no backup")
	}
	if e = writeJSON(journalPath(a.Install), j); e != nil {
		t.Fatal(e)
	}
	if e = recoverInstall(a.Install); e != nil {
		t.Fatal(e)
	}
	old, _ = os.ReadFile(filepath.Join(a.Install, p.Game.Name))
	if string(old) != "old game" {
		t.Fatal("recovery failed")
	}
}
func TestStartupFailureRollback(t *testing.T) {
	if runtime.GOOS != "linux" {
		t.Skip("shell fixture")
	}
	a, m, p := setup(t)
	old := []byte("#!/bin/sh\nexit 0\n")
	bad := []byte("#!/bin/sh\nexit 17\n")
	put(t, filepath.Join(a.Install, p.Game.Name), old)
	put(t, filepath.Join(a.Install, p.Updater.Name), []byte("old helper"))
	p.Game = spec(p.Game.Name, bad)
	m.Platforms[a.Platform] = p
	put(t, filepath.Join(a.Cache, "manifest.json"), signed(t, m))
	ready := filepath.Join(a.Cache, "ready")
	os.Mkdir(ready, 0700)
	put(t, filepath.Join(ready, p.Game.Name), bad)
	put(t, filepath.Join(ready, p.Updater.Name), []byte("new helper"))
	if e := a.apply(0, true); e == nil {
		t.Fatal("accepted crashing game")
	}
	got, _ := os.ReadFile(filepath.Join(a.Install, p.Game.Name))
	if !bytes.Equal(got, old) {
		t.Fatal("did not restore old version")
	}
}
func TestRedirectPolicy(t *testing.T) {
	c := httpClient()
	for _, s := range []string{"http://github.com/a", "https://evil.example/a", "https://github.com.evil.example/a"} {
		r, _ := http.NewRequest("GET", s, nil)
		if c.CheckRedirect(r, nil) == nil {
			t.Fatal("accepted redirect", s)
		}
	}
	r, _ := http.NewRequest("GET", "https://release-assets.githubusercontent.com/a", nil)
	if e := c.CheckRedirect(r, nil); e != nil {
		t.Fatal(e)
	}
}

// Exercise the actual Python release producer against the native client reader.
func TestPythonDeltaCompatibility(t *testing.T) {
	if runtime.GOOS == "windows" {
		t.Skip("Python producer runs on the Linux release builder")
	}
	dir := t.TempDir()
	base := filepath.Join(dir, "base")
	target := filepath.Join(dir, "target")
	helper := filepath.Join(dir, "n-catan-updater")
	archive := filepath.Join(dir, "delta.zip")
	old := bytes.Repeat([]byte("abcdef0123456789"), 16384)
	next := append(append([]byte{}, old[:131072]...), bytes.Repeat([]byte("CHANGED!"), 8192)...)
	next = append(next, old[196608:]...)
	os.WriteFile(base, old, 0600)
	os.WriteFile(target, next, 0600)
	os.WriteFile(helper, []byte("updater"), 0600)
	cmd := exec.Command("python3", "../tools/make_delta.py", "--base", base, "--target", target, "--helper", helper, "--output", archive)
	if output, err := cmd.CombinedOutput(); err != nil {
		t.Fatalf("producer: %v: %s", err, output)
	}
	z, err := zip.OpenReader(archive)
	if err != nil {
		t.Fatal(err)
	}
	defer z.Close()
	sum, _ := hashFile(target)
	baseSum, _ := hashFile(base)
	err = reconstruct(&z.Reader, base, filepath.Join(dir, "result"), FileSpec{Name: "target", Size: int64(len(next)), SHA256: sum}, baseSum)
	if err != nil {
		t.Fatal(err)
	}
}
