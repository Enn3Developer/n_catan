extends PanelContainer
## One notification: a message, an optional action and a dismiss button. It
## dismisses itself when its timer runs out.

signal acted
signal dismissed

func show_notice(message: String,action_text: String,has_action: bool,seconds: float):
	%Message.text=message
	%Action.text=action_text
	%Action.visible=has_action
	if seconds>0:$Timer.start(seconds)
