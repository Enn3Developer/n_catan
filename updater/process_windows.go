//go:build windows

package main

import "syscall"

func processAlive(pid int) bool {
	h, e := syscall.OpenProcess(0x00100000, false, uint32(pid))
	if e != nil {
		return false
	}
	defer syscall.CloseHandle(h)
	state, e := syscall.WaitForSingleObject(h, 0)
	return e == nil && state == 258
}
