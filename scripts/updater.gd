class_name CatanUpdater
extends Node

signal changed
var status={"state":"idle","message":"Check for a newer release."}
var pid=-1
var installing=false
var supported=false
var cache=""
var helper=""
var install_dir=""
var clock=0.0

func _ready():
	cache=ProjectSettings.globalize_path("user://updates")
	install_dir=OS.get_executable_path().get_base_dir()
	var windows=OS.get_name()=="Windows"
	var expected="N Catan.exe" if windows else "N Catan.x86_64"
	helper=install_dir.path_join("n-catan-updater.exe" if windows else "n-catan-updater")
	# Never replace the editor, a renamed executable, or a source checkout.
	supported=OS.get_name() in ["Linux","Windows"] and OS.get_executable_path().get_file()==expected and FileAccess.file_exists(helper)
	if not supported:
		status={"state":"unavailable","message":"Automatic updates are available in installed releases. Download a release with the updater included."}
	changed.emit()

func busy() -> bool:
	return pid>0 and OS.is_process_running(pid)

func check_updates():
	if not supported or busy():return
	_launch("check")

func download_update():
	if not supported or busy() or status.get("state","")!="available":return
	_launch("download")

func install_update(active_session: bool) -> bool:
	if active_session:
		status.message="Leave the current room before restarting to update."
		changed.emit()
		return false
	if not supported or busy() or status.get("state","")!="ready":return false
	var runner=cache.path_join("runner-"+Crypto.new().generate_random_bytes(8).hex_encode()+ (".exe" if OS.get_name()=="Windows" else ""))
	var err=DirAccess.copy_absolute(helper,runner)
	if err==OK and OS.get_name()=="Linux":err=FileAccess.set_unix_permissions(runner,FileAccess.UNIX_READ_OWNER|FileAccess.UNIX_WRITE_OWNER|FileAccess.UNIX_EXECUTE_OWNER)
	if err!=OK:
		status={"state":"error","message":"Could not start the updater. Check free space and folder permissions."};changed.emit();return false
	installing=true
	if not _launch("apply",runner):installing=false;return false
	return true

func _launch(mode: String,executable: String="") -> bool:
	if DirAccess.make_dir_recursive_absolute(cache)!=OK:
		status={"state":"error","message":"Cannot write the update cache."};changed.emit();return false
	DirAccess.remove_absolute(cache.path_join("status.json"))
	status={"state":"checking" if mode=="check" else "downloading" if mode=="download" else "installing","message":"Checking for updates…" if mode=="check" else "Preparing update…"}
	var args=PackedStringArray(["--mode",mode,"--cache",cache,"--install-dir",install_dir,"--current-version",CatanBuildInfo.VERSION])
	if mode=="apply":args.append_array(["--wait-pid",str(OS.get_process_id()),"--restart"])
	pid=OS.create_process(helper if executable.is_empty() else executable,args)
	if pid<0:status={"state":"error","message":"The updater could not be started."}
	changed.emit()
	return pid>0

func _process(delta: float):
	if pid<=0 or installing:return
	clock-=delta
	if clock>0:return
	clock=.25
	var path=cache.path_join("status.json")
	if FileAccess.file_exists(path):
		var file=FileAccess.open(path,FileAccess.READ)
		if file!=null and file.get_length()<65536:
			var data=JSON.parse_string(file.get_as_text())
			if data is Dictionary and data.get("state","") in ["checking","current","available","downloading","preparing","ready","installed","error"]:
				status=data;changed.emit()
	if not OS.is_process_running(pid):
		pid=-1
		if status.get("state","") not in ["current","available","ready","installed","error"]:
			status={"state":"error","message":"The updater stopped. Your installed game has not been changed. Try again."}
		changed.emit()

func _exit_tree():
	if not installing and busy():OS.kill(pid)
