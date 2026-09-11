package main

import (
	"crypto"
	"crypto/rsa"
	"crypto/sha256"
	"crypto/x509"
	_ "embed"
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"regexp"
	"strconv"
	"strings"
)

const repository = "Enn3Developer/n_catan"
const manifestURL = "https://github.com/" + repository + "/releases/latest/download/update-manifest.json"
const maxManifest = 1 << 20
const maxBinary = 1 << 30

//go:embed update_public.pem
var publicPEM []byte

type FileSpec struct {
	Name   string `json:"name"`
	Size   int64  `json:"size"`
	SHA256 string `json:"sha256"`
}
type DeltaSpec struct {
	FromVersion string   `json:"from_version"`
	BaseSHA256  string   `json:"base_sha256"`
	Asset       FileSpec `json:"asset"`
}
type Platform struct {
	Game    FileSpec    `json:"game"`
	Updater FileSpec    `json:"updater"`
	Full    FileSpec    `json:"full"`
	Deltas  []DeltaSpec `json:"deltas,omitempty"`
}
type Manifest struct {
	Format     int                 `json:"format"`
	Version    string              `json:"version"`
	Protocol   int                 `json:"protocol"`
	Repository string              `json:"repository"`
	Commit     string              `json:"commit"`
	Platforms  map[string]Platform `json:"platforms"`
}
type Envelope struct {
	Payload   string `json:"payload"`
	Signature string `json:"signature"`
}

var tagPattern = regexp.MustCompile(`^v?(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-([0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*))?$`)
var namePattern = regexp.MustCompile(`^[A-Za-z0-9][A-Za-z0-9 ._-]{0,180}$`)
var digestPattern = regexp.MustCompile(`^[a-f0-9]{64}$`)
var commitPattern = regexp.MustCompile(`^[a-f0-9]{40}$`)

func parseVersion(s string) ([]uint64, []string, error) {
	m := tagPattern.FindStringSubmatch(s)
	if m == nil {
		return nil, nil, fmt.Errorf("invalid release version %q", s)
	}
	n := make([]uint64, 3)
	for i := range n {
		v, e := strconv.ParseUint(m[i+1], 10, 32)
		if e != nil {
			return nil, nil, e
		}
		n[i] = v
	}
	var pre []string
	if m[4] != "" {
		pre = strings.Split(m[4], ".")
		for _, v := range pre {
			if len(v) > 1 && v[0] == '0' {
				if _, e := strconv.ParseUint(v, 10, 64); e == nil {
					return nil, nil, errors.New("leading zero in prerelease")
				}
			}
		}
	}
	return n, pre, nil
}
func compareVersions(a, b string) (int, error) {
	av, ap, e := parseVersion(a)
	if e != nil {
		return 0, e
	}
	bv, bp, e := parseVersion(b)
	if e != nil {
		return 0, e
	}
	for i := 0; i < 3; i++ {
		if av[i] < bv[i] {
			return -1, nil
		}
		if av[i] > bv[i] {
			return 1, nil
		}
	}
	if len(ap) == 0 && len(bp) > 0 {
		return 1, nil
	}
	if len(bp) == 0 && len(ap) > 0 {
		return -1, nil
	}
	for i := 0; i < len(ap) && i < len(bp); i++ {
		if ap[i] == bp[i] {
			continue
		}
		an, ae := strconv.ParseUint(ap[i], 10, 64)
		bn, be := strconv.ParseUint(bp[i], 10, 64)
		if ae == nil && be == nil {
			if an < bn {
				return -1, nil
			}
			return 1, nil
		}
		if ae == nil {
			return -1, nil
		}
		if be == nil {
			return 1, nil
		}
		if ap[i] < bp[i] {
			return -1, nil
		}
		return 1, nil
	}
	if len(ap) < len(bp) {
		return -1, nil
	}
	if len(ap) > len(bp) {
		return 1, nil
	}
	return 0, nil
}
func readManifest(data, keyPEM []byte) (Manifest, error) {
	var m Manifest
	if len(data) > maxManifest {
		return m, errors.New("manifest too large")
	}
	var env Envelope
	if e := json.Unmarshal(data, &env); e != nil {
		return m, e
	}
	raw, e := base64.StdEncoding.DecodeString(env.Payload)
	if e != nil {
		return m, e
	}
	sig, e := base64.StdEncoding.DecodeString(env.Signature)
	if e != nil {
		return m, e
	}
	block, _ := pem.Decode(keyPEM)
	if block == nil {
		return m, errors.New("missing update public key")
	}
	key, e := x509.ParsePKIXPublicKey(block.Bytes)
	if e != nil {
		return m, e
	}
	rsaKey, ok := key.(*rsa.PublicKey)
	if !ok || rsaKey.N.BitLen() < 2048 {
		return m, errors.New("invalid update public key")
	}
	sum := sha256.Sum256(raw)
	if e = rsa.VerifyPKCS1v15(rsaKey, crypto.SHA256, sum[:], sig); e != nil {
		return m, errors.New("update signature verification failed")
	}
	if e = json.Unmarshal(raw, &m); e != nil {
		return m, e
	}
	if m.Format != 1 || m.Repository != repository || m.Protocol < 1 || !commitPattern.MatchString(m.Commit) {
		return m, errors.New("unsupported or invalid update manifest")
	}
	if _, _, e = parseVersion(m.Version); e != nil {
		return m, e
	}
	if len(m.Platforms) == 0 || len(m.Platforms) > 2 {
		return m, errors.New("invalid platform list")
	}
	for id, p := range m.Platforms {
		game, helper, e := platformNames(id)
		if e != nil {
			return m, e
		}
		if p.Game.Name != game || p.Updater.Name != helper {
			return m, errors.New("unexpected executable name")
		}
		for _, f := range []FileSpec{p.Game, p.Updater, p.Full} {
			if e = validFile(f); e != nil {
				return m, e
			}
		}
		if p.Updater.Size > 64<<20 || len(p.Deltas) > 8 {
			return m, errors.New("update exceeds safety limits")
		}
		if !strings.HasSuffix(p.Full.Name, ".zip") {
			return m, errors.New("invalid full archive")
		}
		for _, d := range p.Deltas {
			if !digestPattern.MatchString(d.BaseSHA256) {
				return m, errors.New("invalid delta base")
			}
			if _, _, e = parseVersion(d.FromVersion); e != nil {
				return m, e
			}
			if e = validFile(d.Asset); e != nil {
				return m, e
			}
		}
	}
	return m, nil
}
func platformNames(id string) (string, string, error) {
	switch id {
	case "linux-x86_64":
		return "N Catan.x86_64", "n-catan-updater", nil
	case "windows-x86_64":
		return "N Catan.exe", "n-catan-updater.exe", nil
	}
	return "", "", errors.New("unsupported operating system or CPU")
}
func validFile(f FileSpec) error {
	if !namePattern.MatchString(f.Name) || strings.Contains(f.Name, "..") || !digestPattern.MatchString(f.SHA256) || f.Size < 1 || f.Size > maxBinary {
		return errors.New("invalid update file metadata")
	}
	return nil
}
func hashFile(path string) (string, error) {
	f, e := os.Open(path)
	if e != nil {
		return "", e
	}
	defer f.Close()
	h := sha256.New()
	if _, e = io.Copy(h, f); e != nil {
		return "", e
	}
	return hex.EncodeToString(h.Sum(nil)), nil
}
func verifyFile(path string, spec FileSpec) error {
	st, e := os.Lstat(path)
	if e != nil {
		return e
	}
	if !st.Mode().IsRegular() || st.Size() != spec.Size {
		return fmt.Errorf("wrong file size or type: %s", spec.Name)
	}
	sum, e := hashFile(path)
	if e != nil {
		return e
	}
	if sum != spec.SHA256 {
		return fmt.Errorf("checksum mismatch: %s", spec.Name)
	}
	return nil
}
func assetURL(version, name string) string {
	return "https://github.com/" + repository + "/releases/download/" + version + "/" + strings.ReplaceAll(name, " ", "%20")
}
func chooseDelta(p Platform, install string) *DeltaSpec {
	sum, e := hashFile(filepath.Join(install, p.Game.Name))
	if e != nil {
		return nil
	}
	var best *DeltaSpec
	for i := range p.Deltas {
		d := &p.Deltas[i]
		if d.BaseSHA256 == sum && d.Asset.Size < p.Full.Size*85/100 && (best == nil || d.Asset.Size < best.Asset.Size) {
			best = d
		}
	}
	return best
}
