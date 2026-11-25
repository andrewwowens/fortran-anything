! The port: same behavior as demo/original/roman.py, checked case by case.
program roman
  implicit none

  integer, parameter :: values(13) = &
    [1000, 900, 500, 400, 100, 90, 50, 40, 10, 9, 5, 4, 1]
  character(len=2), parameter :: symbols(13) = &
    ['M ', 'CM', 'D ', 'CD', 'C ', 'XC', 'L ', 'XL', 'X ', 'IX', 'V ', 'IV', 'I ']

  character(len=:), allocatable :: text
  integer :: n, length

  if (command_argument_count() /= 1) then
    write (0, '(A)') 'usage: roman <number|numeral>'
    stop 1, quiet=.true.
  end if

  call get_command_argument(1, length=length)
  allocate (character(len=length) :: text)
  if (length > 0) call get_command_argument(1, text)

  if (length > 0 .and. verify(text, '0123456789') == 0) then
    n = parse_number(text)
    if (n < 1 .or. n > 3999) then
      write (0, '(A)') 'out of range'
      stop 2, quiet=.true.
    end if
    write (*, '(A)') to_roman(n)
  else
    n = from_roman(upper(text))
    if (n == 0) then
      write (0, '(A)') 'not a numeral'
      stop 2, quiet=.true.
    end if
    write (*, '(I0)') n
  end if

contains

  ! Digits only. Anything too long to be in range comes back as 4000.
  function parse_number(s) result(n)
    character(len=*), intent(in) :: s
    integer :: n, first
    first = verify(s, '0')
    if (first == 0) then
      n = 0
    else if (len(s) - first + 1 > 4) then
      n = 4000
    else
      read (s(first:), *) n
    end if
  end function parse_number

  function to_roman(number) result(out)
    integer, intent(in) :: number
    character(len=:), allocatable :: out
    integer :: i, left
    out = ''
    left = number
    do i = 1, size(values)
      do while (left >= values(i))
        out = out//trim(symbols(i))
        left = left - values(i)
      end do
    end do
  end function to_roman

  ! Returns 0 when s is not a canonical numeral.
  function from_roman(s) result(n)
    character(len=*), intent(in) :: s
    integer :: n, i, pos, width
    n = 0
    pos = 1
    do i = 1, size(values)
      width = len_trim(symbols(i))
      do while (pos + width - 1 <= len(s))
        if (s(pos:pos + width - 1) /= trim(symbols(i))) exit
        n = n + values(i)
        pos = pos + width
      end do
    end do
    if (pos <= len(s) .or. n < 1 .or. n > 3999) then
      n = 0
    else if (to_roman(n) /= s) then
      n = 0
    end if
  end function from_roman

  function upper(s) result(out)
    character(len=*), intent(in) :: s
    character(len=len(s)) :: out
    integer :: i, c
    do i = 1, len(s)
      c = iachar(s(i:i))
      if (c >= iachar('a') .and. c <= iachar('z')) c = c - 32
      out(i:i) = achar(c)
    end do
  end function upper

end program roman
