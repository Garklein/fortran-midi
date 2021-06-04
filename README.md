# fortran-midi
A Fortran library for writing to MIDI files

## The files
There are 3 files here: midi-writermod.f90, endian.f90, and endmsg.f90.  
[midi-writermod.f90](https://github.com/Garklein/fortran-midi/blob/main/midi-writermod.f90) has all the midi writing stuff.  
[endian.f90](https://github.com/Garklein/fortran-midi/blob/main/endian.f90) just has functions to do endian swaps.  
[endmsg.f90](https://github.com/Garklein/fortran-midi/blob/main/endmsg.f90) just contains one subroutine that prints "press enter to exit", then stops the program.  

## Using this library
To use this library in a program, simply copy all 3 files into the folder with your program, and include `use midiWriter` at the top of your program.

## Compiling
You can use whatever Fortran compiler you want to compile this.  
My examples will be with GFortran, since that's what I used when testing and it's what I'm familiar with.  
`gfortran -c endmsg.f90`  
`gfortran -c endian.f90`  
`gfortran -c midi-writermod.f90`  
`gfortran yourprogram.f90 endmsg.o endian.o midi-writermod.o`

## Subroutines

### [createFile(filename, bpm)](https://github.com/Garklein/fortran-midi/blob/48a40ead56586608485f4d5678b37d9897e85fb8/midi-writermod.f90#L46)
```
character(*), intent(in) :: fileName
integer, intent(in) :: bpm
```
Pretty self-explanatory.  
In your main program, you need to set the `nOfTracks` int to the number of tracks you're using before you call this.  

### [newTrack(instrument)](https://github.com/Garklein/fortran-midi/blob/48a40ead56586608485f4d5678b37d9897e85fb8/midi-writermod.f90#L73)
```
integer, intent(in) :: instrument
```
Initializes a new track, with the supplied instrument (number from 0-127).

### [endTrack()](https://github.com/Garklein/fortran-midi/blob/48a40ead56586608485f4d5678b37d9897e85fb8/midi-writermod.f90#L204)
Ends the current track. Every newTrack call should be paired with an endTrack one.

### [addNote(note, beats, velocity)](https://github.com/Garklein/fortran-midi/blob/48a40ead56586608485f4d5678b37d9897e85fb8/midi-writermod.f90#L120)
```
integer, intent(in) :: note
real, intent(in) :: beats
integer, intent(in), optional :: velocity
```
Adds a note to the current track. Google the MIDI note numbers to know which numbers are what notes.  
Optional velocity param that defaults to 96.

### [addRest(beats)](https://github.com/Garklein/fortran-midi/blob/48a40ead56586608485f4d5678b37d9897e85fb8/midi-writermod.f90#L154)
```
real, intent(in) :: beats
```
Adds a rest to the current track.

## Fancy subroutines
If you really want to get fancy and do stuff such as specify note on and note off times (for chords or something), I got you covered.  
For every noteOn, you need to have a noteOff after it on the same note.  
To specify spaces between noteOn and noteOff, use the addRest function (which is really an addDeltaTime function).  

### [noteOn(note, velocity)](https://github.com/Garklein/fortran-midi/blob/48a40ead56586608485f4d5678b37d9897e85fb8/midi-writermod.f90#L158)
```
integer, intent(in) :: note
integer, intent(in), optional :: velocity
```
Adds a note to the current track without its noteOff message. See addNote above.

### [noteOff(note)](https://github.com/Garklein/fortran-midi/blob/48a40ead56586608485f4d5678b37d9897e85fb8/midi-writermod.f90#L184)
```
integer, intent(in) :: note
```
Makes a noteOff message. See above function.

## Unimplemented features
- Custom time signatures  
You can work around this, and I didn't need it, so I didn't put it in.
- Key signatures and other midi events  
Again, I didn't need this, so I didn't implement it.  
I think there are enough comments that if you wanted to implement it, you could do so easily.
