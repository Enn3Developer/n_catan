package main

import (
	"context"
	"flag"
	"fmt"
	"os"
	"path/filepath"
	"runtime"
)

func platformID() string {
	if runtime.GOARCH != "amd64" {
		return "unsupported"
	}
	return runtime.GOOS + "-x86_64"
}
func main() {
	mode := flag.String("mode", "launch", "check, download, apply, recover, or launch")
	cache := flag.String("cache", "", "update cache directory")
	install := flag.String("install-dir", "", "installation directory")
	version := flag.String("current-version", "0.0.0-dev", "running game version")
	pid := flag.Int("wait-pid", 0, "game process to wait for")
	restart := flag.Bool("restart", false, "restart and verify the updated game")
	flag.Parse()
	self, e := os.Executable()
	if e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
	if *install == "" {
		*install = filepath.Dir(self)
	}
	*install, e = filepath.Abs(*install)
	if e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
	if *mode == "launch" {
		e = launch(*install)
	} else if *mode == "recover" {
		e = waitForExit(*pid)
		if e == nil {
			e = recoverInstall(*install)
		}
		if e == nil {
			e = launch(*install)
		}
	} else {
		if *cache == "" {
			fmt.Fprintln(os.Stderr, "cache directory is required")
			os.Exit(1)
		}
		*cache, e = filepath.Abs(*cache)
		if e == nil {
			e = os.MkdirAll(*cache, 0700)
		}
		if e != nil {
			fmt.Fprintln(os.Stderr, e)
			os.Exit(1)
		}
		a := &App{Cache: *cache, Install: *install, CurrentVersion: *version, Platform: platformID(), Client: httpClient()}
		switch *mode {
		case "check":
			e = a.check(context.Background())
		case "download":
			e = a.download(context.Background())
		case "apply":
			e = a.apply(*pid, *restart)
		default:
			e = fmt.Errorf("unknown mode %q", *mode)
		}
		if e != nil {
			a.report("error", e.Error())
		}
	}
	if e != nil {
		fmt.Fprintln(os.Stderr, e)
		os.Exit(1)
	}
}
