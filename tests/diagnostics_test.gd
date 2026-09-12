extends SceneTree
var failures=0
func check(ok,message):
	if not ok:failures+=1;printerr("FAIL: ",message)
func _initialize():call_deferred("run")
func run():
	var folder="/tmp/catan-diagnostics-test-%d"%OS.get_process_id()
	var sink=CatanDiagnostics.Sink.new(folder)
	for i in 1000:sink.write("TEST","same repeated message")
	var content=FileAccess.get_file_as_string(folder+"/diagnostics.log")
	check(content.count("same repeated message")==1,"repeated errors suppressed")
	sink.write("TEST","password=hunter2 token=abc 192.0.2.42:123 n-catan://secret NC1-AbcdEf01234_-xyz")
	content=FileAccess.get_file_as_string(folder+"/diagnostics.log")
	check(not content.contains("hunter2") and not content.contains("192.0.2.42") and not content.contains("token=abc"),"sensitive diagnostics redacted")
	check(not content.contains("NC1-AbcdEf01234_-xyz"),"compact invites redacted")
	check(content.contains("Suppressed 999"),"suppression count reported")
	sink.window_count=60
	sink.write("TEST","rate limited unique message")
	check(not FileAccess.get_file_as_string(folder+"/diagnostics.log").contains("rate limited unique message"),"unique message floods rate limited")
	for i in 2000:
		sink.window_count=0
		sink.write("TEST","%d "%i+"x".repeat(4096))
	for suffix in ["",".1",".2",".3"]:
		var file=FileAccess.open(folder+"/diagnostics.log"+suffix,FileAccess.READ)
		check(file!=null and file.get_length()<=sink.LIMIT,"rotated file exists within hard byte cap")
	check(not FileAccess.file_exists(folder+"/diagnostics.log.4"),"retention capped at four files")
	OS.add_logger(sink)
	push_error("intentional diagnostic test error")
	OS.remove_logger(sink)
	content=FileAccess.get_file_as_string(folder+"/diagnostics.log")
	check(content.contains("intentional diagnostic test error") and content.contains("diagnostics_test.gd"),"engine error captures source and stack")
	print("DIAGNOSTICS_TEST: ",failures," failures")
	quit(1 if failures else 0)
