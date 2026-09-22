extends CatanDialog
## Release status from the updater, with the check, download and install steps.

signal check_requested
signal download_requested
signal install_requested

func _ready():
	%Installed.text=tr("Installed: %s · Multiplayer protocol %d") % [CatanBuildInfo.VERSION,CatanBuildInfo.PROTOCOL]

func show_status(data: Dictionary,supported: bool,busy: bool,online: bool):
	var stage=data.get("state","idle")
	%UpdateMessage.text=CatanI18n.update_message(data)
	var details=tr("Updates are verified before installation. Downloads can run in the background.")
	if data.get("total",0)>0:
		details=tr("%s download · %.1f MiB") % [tr("Delta") if data.get("kind","")=="delta" else tr("Full"),float(data.total)/1048576.0]
	if data.has("version"):details+=tr("\nRelease %s · Protocol %d") % [data.version,data.get("protocol",CatanBuildInfo.PROTOCOL)]
	if data.get("protocol",CatanBuildInfo.PROTOCOL)!=CatanBuildInfo.PROTOCOL:details+=tr("\nThis release changes multiplayer compatibility. Your group should update together.")
	if online:details+=tr("\nLeave this room before installing; hosting an update would close it.")
	%UpdateDetails.text=details
	%UpdateProgress.visible=stage in ["downloading","preparing"]
	%UpdateProgress.value=100.0*float(data.get("bytes",0))/maxf(1,float(data.get("total",0)))
	%UpdateCheck.disabled=not supported or busy
	%UpdateDownload.visible=stage=="available"
	%UpdateDownload.disabled=busy
	%UpdateInstall.visible=stage=="ready"
	%UpdateInstall.disabled=online or busy
