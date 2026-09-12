class_name CatanDiagnostics
extends Node

# Capture engine errors and intentional breadcrumbs, never arbitrary stdout (which
# includes dedicated-server invites). Four 1 MiB files bound storage per user.
class Sink extends Logger:
	const LIMIT=1048576
	var directory: String
	var file: FileAccess
	var mutex=Mutex.new()
	var recent={}
	var window_ms=0
	var window_count=0
	var suppressed=0
	var redactor=RegEx.new()
	func _init(folder: String):
		directory=folder
		DirAccess.make_dir_recursive_absolute(directory)
		redactor.compile("(?i)(?:NC1-[A-Za-z0-9_-]+|n-catan://\\S+|(?:[0-9]{1,3}\\.){3}[0-9]{1,3}(?::[0-9]+)?|(?:password|token|invite)\\s*[=:]\\s*\\S+)")
		var path=directory+"/diagnostics.log"
		file=FileAccess.open(path,FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE_READ)
		if file:file.seek_end()
	func write(level: String,message: String):
		# Engine errors during file I/O can reenter this sink. Never deadlock.
		if not mutex.try_lock():return
		var now=Time.get_ticks_msec()
		var clean=redactor.sub(message,"[redacted]",true).replace("\r","").substr(0,4096)
		var key=level+clean
		if now-window_ms>=10000:
			window_ms=now;window_count=0
		if window_count>=60 or (recent.has(key) and now-int(recent[key])<30000):
			suppressed+=1
			mutex.unlock();return
		if recent.size()>=128:recent.clear()
		recent[key]=now;window_count+=1
		var line="%s +%dms [%s] %s\n"%[Time.get_datetime_string_from_system(true),now,level,clean]
		if suppressed>0:
			line="[DIAGNOSTICS] Suppressed %d repeated/rate-limited messages\n"%suppressed+line
			suppressed=0
		var bytes=line.to_utf8_buffer()
		if file and file.get_position()+bytes.size()>LIMIT:_rotate()
		if file:file.store_buffer(bytes);file.flush()
		mutex.unlock()
	func _rotate():
		file.close();file=null
		var path=directory+"/diagnostics.log"
		if FileAccess.file_exists(path+".3"):DirAccess.remove_absolute(path+".3")
		for i in range(2,0,-1):
			if FileAccess.file_exists(path+".%d"%i):DirAccess.rename_absolute(path+".%d"%i,path+".%d"%(i+1))
		DirAccess.rename_absolute(path,path+".1")
		file=FileAccess.open(path,FileAccess.WRITE_READ)
	func _log_message(message: String,error: bool):
		if error:write("STDERR",message)
	func _log_error(function: String,source: String,line: int,code: String,rationale: String,_editor_notify: bool,error_type: int,script_back_traces: Array[ScriptBacktrace]):
		var detail="type=%d %s:%d %s: %s %s"%[error_type,source,line,function,code,rationale]
		for trace in script_back_traces:detail+="\n"+trace.format(0)
		write("ERROR",detail)

static var active: Sink
var health_seconds=0.0

func _enter_tree():
	active=Sink.new(ProjectSettings.globalize_path("user://logs"))
	OS.add_logger(active)
	event("startup","version=%s engine=%s renderer=%s gpu=%s"%[CatanBuildInfo.VERSION,Engine.get_version_info().string,RenderingServer.get_current_rendering_method(),RenderingServer.get_video_adapter_name()])

static func event(label: String,detail: String=""):
	if active:active.write("DEBUG",label+" "+detail)

func _process(delta: float):
	health_seconds+=delta
	if health_seconds<60:return
	health_seconds=0
	event("health","fps=%d nodes=%d memory_mib=%.1f"%[Engine.get_frames_per_second(),Performance.get_monitor(Performance.OBJECT_NODE_COUNT),OS.get_static_memory_usage()/1048576.0])

func _exit_tree():
	event("shutdown","scene tree exit")
	OS.remove_logger(active)
	active=null
