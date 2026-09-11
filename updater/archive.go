package main

import (
	"archive/zip"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

type DeltaOp struct {
	Copy *int64 `json:"copy,omitempty"`
	Size int64  `json:"size"`
}
type DeltaPlan struct {
	Format       int       `json:"format"`
	BaseSHA256   string    `json:"base_sha256"`
	TargetSHA256 string    `json:"target_sha256"`
	TargetSize   int64     `json:"target_size"`
	Ops          []DeltaOp `json:"ops"`
}

func extractFile(z *zip.File, dest string, spec FileSpec) error {
	if z.UncompressedSize64 != uint64(spec.Size) || !z.Mode().IsRegular() {
		return errors.New("invalid archive entry")
	}
	r, e := z.Open()
	if e != nil {
		return e
	}
	defer r.Close()
	f, e := os.OpenFile(dest, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0700)
	if e != nil {
		return e
	}
	_, e = io.CopyN(f, r, spec.Size)
	if e == nil {
		var b [1]byte
		n, tail := r.Read(b[:])
		if n != 0 || tail != io.EOF {
			e = errors.New("archive entry longer than expected")
		}
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
	return verifyFile(dest, spec)
}
func reconstruct(z *zip.Reader, basePath, dest string, spec FileSpec, expectedBase string) error {
	var meta, payload *zip.File
	for _, f := range z.File {
		switch f.Name {
		case "delta.json":
			meta = f
		case "payload.bin":
			payload = f
		}
	}
	if meta == nil || payload == nil || meta.UncompressedSize64 > 8<<20 || payload.UncompressedSize64 > uint64(spec.Size) {
		return errors.New("invalid delta archive")
	}
	r, e := meta.Open()
	if e != nil {
		return e
	}
	raw, e := io.ReadAll(io.LimitReader(r, 8<<20+1))
	r.Close()
	if e != nil {
		return e
	}
	var plan DeltaPlan
	if e = json.Unmarshal(raw, &plan); e != nil {
		return e
	}
	if plan.Format != 1 || plan.BaseSHA256 != expectedBase || plan.TargetSHA256 != spec.SHA256 || plan.TargetSize != spec.Size || len(plan.Ops) > 100000 {
		return errors.New("delta target/base mismatch")
	}
	sum, e := hashFile(basePath)
	if e != nil {
		return e
	}
	if sum != expectedBase {
		return errors.New("installed file changed; full update required")
	}
	base, e := os.Open(basePath)
	if e != nil {
		return e
	}
	defer base.Close()
	st, e := base.Stat()
	if e != nil {
		return e
	}
	literals, e := payload.Open()
	if e != nil {
		return e
	}
	defer literals.Close()
	out, e := os.OpenFile(dest, os.O_CREATE|os.O_EXCL|os.O_WRONLY, 0700)
	if e != nil {
		return e
	}
	total := int64(0)
	for _, op := range plan.Ops {
		if op.Size <= 0 || op.Size > spec.Size-total {
			out.Close()
			return errors.New("delta output bounds exceeded")
		}
		var input io.Reader = literals
		if op.Copy != nil {
			off := *op.Copy
			if off < 0 || off > st.Size() || op.Size > st.Size()-off {
				out.Close()
				return errors.New("delta copy outside base")
			}
			input = io.NewSectionReader(base, off, op.Size)
		}
		if _, e = io.CopyN(out, input, op.Size); e != nil {
			out.Close()
			return e
		}
		total += op.Size
	}
	if total != spec.Size {
		out.Close()
		return errors.New("incomplete delta")
	}
	var b [1]byte
	n, tail := literals.Read(b[:])
	if n != 0 || tail != io.EOF {
		out.Close()
		return errors.New("extra delta literal data")
	}
	if e = out.Sync(); e != nil {
		out.Close()
		return e
	}
	if e = out.Close(); e != nil {
		return e
	}
	return verifyFile(dest, spec)
}
func stageArchive(archivePath, stage, install string, p Platform, delta *DeltaSpec) error {
	z, e := zip.OpenReader(archivePath)
	if e != nil {
		return e
	}
	defer z.Close()
	allowed := map[string]bool{p.Updater.Name: true, "README.txt": true}
	if delta == nil {
		allowed[p.Game.Name] = true
	} else {
		allowed["delta.json"] = true
		allowed["payload.bin"] = true
	}
	entries := map[string]*zip.File{}
	for _, f := range z.File {
		if !allowed[f.Name] || entries[f.Name] != nil || !f.Mode().IsRegular() {
			return fmt.Errorf("unsafe or duplicate archive entry: %s", f.Name)
		}
		entries[f.Name] = f
	}
	helper := entries[p.Updater.Name]
	if helper == nil {
		return errors.New("archive is missing updater")
	}
	if e = os.MkdirAll(stage, 0700); e != nil {
		return e
	}
	if e = extractFile(helper, filepath.Join(stage, p.Updater.Name), p.Updater); e != nil {
		return e
	}
	target := filepath.Join(stage, p.Game.Name)
	if delta == nil {
		game := entries[p.Game.Name]
		if game == nil {
			return errors.New("archive is missing game")
		}
		return extractFile(game, target, p.Game)
	}
	return reconstruct(&z.Reader, filepath.Join(install, p.Game.Name), target, p.Game, delta.BaseSHA256)
}
