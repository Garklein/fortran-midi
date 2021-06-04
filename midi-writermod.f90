module midiWriter
	use iso_fortran_env
	use endMsgMod
	use endian
	implicit none

	integer :: trackNum, trackDT, nOfTracks = 0, trackBpm
	integer(kind=int32) :: trackBytes
	character, dimension(:), allocatable :: track
contains
	! returns an array with the vlq representation of a number
	subroutine vlq(num, array, nOfBytes)
		integer, intent(in) :: num
		integer(kind=int8), dimension(:), allocatable, intent(out) :: array
		integer, intent(out) :: nOfBytes
		integer :: nOfBits, i, mask, byteData
		integer(kind=int8) :: currentByte

		if (num == 0) then
			nOfBytes = 1
			allocate(array(1))
			array = [int(z'00', int8)]
			return
		end if

		nOfBits = log(real(num)) / log(2.0) + 1
		if (nOfBits > 28) then
			print *, "Error: program requested a vlq over 4 bytes"
			call endMsg()
		end if
		nOfBytes = ceiling(real(nOfBits) / 7)
		allocate(array(nOfBytes))
		do i = nOfBytes, 1, -1
			currentByte = 0			
			byteData = 0
			if (i /= nOfBytes) then
				currentByte = ior(currentByte, b'10000000')
			end if
			mask = ishft(b'01111111', (nOfBytes - i) * 7)
			byteData = ishft(iand(num, mask), -(nOfBytes - i) * 7)
			currentByte = ior(currentByte, byteData)
			array(i) = currentByte
		end do
	end subroutine vlq
	! actual functions
	subroutine createFile(fileName, bpm)
		implicit none
		character(*), intent(in) :: fileName
		integer, intent(in) :: bpm
		integer :: err

		if (nOfTracks == 0) then
			print *, "Error: didn't supply amount of tracks"
			call endMsg()
		end if

		open(10, file=(fileName // ".mid"), status="new", iostat=err, access="stream")
		if (err /= 0) then
			print *, "Error creating file '" // (fileName // ".mid") // "', perhaps it already exists"
			call endMsg()
		end if
		
		! writing the header
		write(10) "MThd" ! saying it's a midi file
		write(10) swap(int(z'00000006', int32)) ! header size
		write(10) swap(int(z'0001', int16)) ! file format: multiple simultaneous tracks
		write(10) swap(int(nOfTracks, int16)) ! num of tracks in file
		write(10) swap(int(z'0060', int16)) ! 96 ticks per quarter note

		trackNum = -1
		trackBpm = bpm
	end subroutine createFile
	subroutine newTrack(instrument)
		integer, intent(in) :: instrument
		integer :: bpm
		if (instrument > 127 .or. 0 > instrument) then
			print *, "Error: Invalid instrument requested"
			call endMsg()
		end if

		trackNum = trackNum + 1
		if (trackNum > 15) then
			print *, "Error: Program tried to use more than 15 tracks"
			call endMsg()
		end if

		open(20, status="scratch", access="stream")
		write(10) "MTrk" ! saying it's a track chunk header
		trackBytes = 0

		if (trackNum == 0) then
			! write key/time signature
			write(20) int(z'00', int8) ! delta time
			write(20) swap(int(z'ff58', int16)) ! going to set time signature
			write(20) int(z'04', int8)
			write(20) swap(int(z'0402', int16)) ! top = 4, bottom = 2^-2 (quarter note)
			write(20) swap(int(z'1808', int16)) ! 18 (24 dec) = clocks in metronome tick,
			! 8 32nd notes per quarter note

			bpm = 1000000 / (real(trackBpm) / 60)
			if (iand(bpm, z'ff000000') /= 0) then
				print *, "Invalid tempo: does not fit in 3 bytes"
				call endMsg()
			end if
			write(20) int(z'00', int8) ! delta time
			write(20) swap(int(z'ff51', int16)) ! going to set tempo
			write(20) int(z'03', int8)
			write(20) int( ishft(iand(bpm, z'ff0000'), -16) , int8)
			write(20) int( ishft(iand(bpm, z'ff00'), -8) , int8)
			write(20) int(iand(bpm, z'ff'), int8)

			trackBytes = 15
		end if
	
		write(20) int(z'00', int8) ! delta time
		write(20) int(ior(z'c0', trackNum), int8) ! program change, whatever track it's on
		write(20) int(instrument, int8) ! change to whatever instrument was requested
		trackBytes = trackBytes + 3
	end subroutine newTrack
	subroutine addNote(note, beats, velocity)
		integer, intent(in) :: note
		real, intent(in) :: beats
		integer, intent(in), optional :: velocity
		integer :: nOfDeltaTimeBytes
		integer(kind=int8), dimension(:), allocatable :: deltaTimeBytes, durationDeltaTimeBytes
		if (note > 255 .or. 0 > note) then
			print *, "Error: Program tried to use a note that is too high or too low"
			call endMsg()
		end if

		! setting note delta time in vlq format
		call vlq(trackDT, deltaTimeBytes, nOfDeltaTimeBytes)
		trackBytes = trackBytes + nOfDeltaTimeBytes
		write(20) deltaTimeBytes ! delta time note
		write(20) int(ior(z'90', trackNum), int8) ! event noteon, track whatever it's on
		write(20) int(note, int8) ! whichever note was requested
		if (.not. present(velocity)) then
			write(20) int(z'60', int8) ! 96 velocity
		else
			write(20) int(velocity, int8)
		end if

		! setting note duration delta time in vlq format (1 beat = 96 ticks)
		call vlq(int(beats * 96), durationDeltaTimeBytes, nOfDeltaTimeBytes)
		trackBytes = trackBytes + nOfDeltaTimeBytes
		write(20) durationDeltaTimeBytes
		write(20) int(ior(z'80', trackNum), int8) ! noteoff, track whatever it's on
		write(20) int(note, int8) ! whatever note was requested
		write(20) int(z'40', int8) ! velocity standard

		trackDT = 0
		trackBytes = trackBytes + 6
	end subroutine addNote
	subroutine addRest(beats)
		real, intent(in) :: beats
		trackDT = trackDT + int(beats * 96)
	end subroutine addRest
	subroutine noteOn(note, velocity)
		integer, intent(in) :: note
		integer, intent(in), optional :: velocity
		integer :: nOfDeltaTimeBytes
		integer(kind=int8), dimension(:), allocatable :: deltaTimeBytes
		if (note > 255 .or. 0 > note) then
			print *, "Error: Program tried to use a note that is too high or too low"
			print *, note
			call endMsg()
		end if

		! setting note delta time in vlq format
		call vlq(trackDT, deltaTimeBytes, nOfDeltaTimeBytes)
		trackBytes = trackBytes + nOfDeltaTimeBytes
		write(20) deltaTimeBytes ! delta time note
		write(20) int(ior(z'90', trackNum), int8) ! event noteon, track whatever it's on
		write(20) int(note, int8) ! whichever note was requested
		if (.not. present(velocity)) then
			write(20) int(z'60', int8) ! 96 velocity
		else
			write(20) int(velocity, int8)
		end if

		trackDT = 0
		trackBytes = trackBytes + 3
	end subroutine noteOn
	subroutine noteOff(note)
		integer, intent(in) :: note
		integer :: nOfDeltaTimeBytes
		integer(kind=int8), dimension(:), allocatable :: deltaTimeBytes
		if (note > 255 .or. 0 > note) then
			print *, "Error: Program tried to use a note that is too high or too low"
			call endMsg()
		end if

		! setting note duration delta time in vlq format (1 beat = 96 ticks)
		call vlq(trackDT, deltaTimeBytes, nOfDeltaTimeBytes)
		trackBytes = trackBytes + nOfDeltaTimeBytes
		write(20) deltaTimeBytes
		write(20) int(ior(z'80', trackNum), int8) ! noteoff, track whatever it's on
		write(20) int(note, int8) ! whatever note was requested
		write(20) int(z'40', int8) ! velocity standard

		trackDT = 0
		trackBytes = trackBytes + 3
	end subroutine noteOff
	subroutine endTrack()
		write(20) swap(int(z'00ff2f00', int32)) ! end of track event
		trackBytes = trackBytes + 4

		write(10) swap(trackBytes) ! writing # of bytes for track header

		! writing the scratch file to track
		allocate(track(trackBytes))
		rewind(20)
		read(20, end=1000) track
		1000 continue
		close(20)	
		! writing track to the main file
		write(10) track
		deallocate(track)
	end subroutine endTrack
end module midiWriter
