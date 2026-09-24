extends Control
## The lesson card shown above the board during guided practice.

signal step_requested(direction: int)
signal restart_requested

func show_lesson(guide: CatanTutorial):
	%Progress.text=tr("LESSON %d / %d") % [guide.step+1,CatanTutorial.LESSONS.size()]
	%LessonTitle.text=guide.current().title
	%LessonBody.text=guide.current().body
	%LessonStatus.text=tr("WELL DONE") if guide.completed and not guide.current().action.is_empty() else ""
	%NextLesson.disabled=not guide.completed
	%NextLesson.text=tr("Play solo  →") if guide.step==CatanTutorial.LESSONS.size()-1 else tr("Continue  →")
	%PreviousLesson.disabled=guide.step==0
