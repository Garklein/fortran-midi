module endMsgMod
contains
	subroutine endMsg()
		print *, "Press enter to continue"
		read *
		stop
	end subroutine endMsg
end module endMsgMod
