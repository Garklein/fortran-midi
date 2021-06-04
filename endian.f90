module endian
	use iso_fortran_env
	interface swap
		! swapping between big endian and little endian
		! functions for 4 bytes, 2 bytes, and 1 byte
		procedure swap32, swap16, swap8
	end interface swap
contains
	! endian stuff
	integer(kind=int32) function swap32(input) result(num)
		implicit none
		integer(kind=int32), intent(in) :: input
		integer :: byte1, byte2, byte3, byte4
		byte1 = ishft(and(input, z'000000ff'), 24)
		byte2 = ishft(and(input, z'0000ff00'), 8)
		byte3 = ishft(and(input, z'00ff0000'), -8)
		byte4 = ishft(and(input, z'ff000000'), -24)
		num = ior(byte1, ior(byte2, ior(byte3, byte4))) 
	end function swap32
	integer(kind=int16) function swap16(input) result(num)
		implicit none
		integer(kind=int16), intent(in) :: input
		integer :: byte1, byte2
		byte1 = ishft(and(input, z'00ff'), 8)
		byte2 = ishft(and(input, z'ff00'), -8)
		num = ior(byte1, byte2)
	end function swap16
	integer(kind=int8) function swap8(input) result(num)
		implicit none
		integer(kind=int8), intent(in) :: input
		integer :: byte1
		byte1 = ishft(and(input, z'ff'), 0)
		num = byte1
	end function swap8
end module endian
