! fortran-anything: rewrite a CLI in Fortran, one piece at a time, and
! check every piece against the original's recorded behavior.
!
!   record   run the original on every case and save stdout + exit code
!   diff     replay every recorded case against the Fortran port
!   gate     pass only if the last diff matched every case
program fortran_anything
  implicit none

  integer, parameter :: line_len = 4096
  character(len=:), allocatable :: sub, dir, cases_file, command
  integer :: status

  dir = '.fortran-anything'
  cases_file = 'cases.txt'
  command = ''
  status = 0

  if (command_argument_count() < 1) then
    call usage()
    stop 1, quiet=.true.
  end if

  sub = arg(1)
  call parse_options()

  select case (sub)
  case ('record')
    call need_command()
    call record(status)
  case ('diff')
    call need_command()
    call replay(status)
  case ('gate')
    call gate(status)
  case ('help', '--help', '-h')
    call usage()
  case default
    write (0, '(A)') 'fortran-anything: unknown command "'//sub//'"'
    call usage()
    status = 1
  end select

  if (status /= 0) stop status, quiet=.true.

contains

  subroutine usage()
    write (0, '(A)') 'usage:'
    write (0, '(A)') '  fortran-anything record [--cases FILE] [--dir DIR] -- <original command>'
    write (0, '(A)') '  fortran-anything diff   [--dir DIR] -- <fortran command>'
    write (0, '(A)') '  fortran-anything gate   [--dir DIR]'
    write (0, '(A)') ''
    write (0, '(A)') 'FILE holds one case per line: the arguments (and any "< input"'
    write (0, '(A)') 'redirect) to append to the command. Blank lines and # lines are skipped.'
    write (0, '(A)') 'Defaults: --cases cases.txt, --dir .fortran-anything'
  end subroutine usage

  function arg(i) result(value)
    integer, intent(in) :: i
    character(len=:), allocatable :: value
    integer :: n
    call get_command_argument(i, length=n)
    allocate (character(len=n) :: value)
    if (n > 0) call get_command_argument(i, value)
  end function arg

  ! Wrap a word in single quotes so the shell passes it through untouched.
  function shell_quote(word) result(quoted)
    character(len=*), intent(in) :: word
    character(len=:), allocatable :: quoted
    integer :: i
    quoted = "'"
    do i = 1, len(word)
      if (word(i:i) == "'") then
        quoted = quoted//"'\''"
      else
        quoted = quoted//word(i:i)
      end if
    end do
    quoted = quoted//"'"
  end function shell_quote

  subroutine parse_options()
    integer :: i, n
    character(len=:), allocatable :: a
    n = command_argument_count()
    i = 2
    do while (i <= n)
      a = arg(i)
      if (a == '--') then
        do i = i + 1, n
          if (len(command) > 0) command = command//' '
          command = command//shell_quote(arg(i))
        end do
        return
      else if (a == '--cases' .and. i < n) then
        cases_file = arg(i + 1)
        i = i + 2
      else if (a == '--dir' .and. i < n) then
        dir = arg(i + 1)
        i = i + 2
      else
        write (0, '(A)') 'fortran-anything: unexpected argument "'//a//'"'
        call usage()
        stop 1, quiet=.true.
      end if
    end do
  end subroutine parse_options

  subroutine need_command()
    if (len(command) == 0) then
      write (0, '(A)') 'fortran-anything: '//sub//' needs a command after --'
      stop 1, quiet=.true.
    end if
  end subroutine need_command

  function case_path(folder, i, ext) result(path)
    character(len=*), intent(in) :: folder, ext
    integer, intent(in) :: i
    character(len=:), allocatable :: path
    character(len=4) :: num
    write (num, '(I4.4)') i
    path = dir//'/'//folder//'/'//num//'.'//ext
  end function case_path

  subroutine shell(cmd, code)
    character(len=*), intent(in) :: cmd
    integer, intent(out) :: code
    integer :: cmdstat
    code = 0
    call execute_command_line(cmd, exitstat=code, cmdstat=cmdstat)
    if (cmdstat /= 0) code = 127
  end subroutine shell

  ! Run one case, sending stdout and stderr to files. Returns the exit code.
  subroutine run_case(cmd, fragment, base, code)
    character(len=*), intent(in) :: cmd, fragment, base
    integer, intent(out) :: code
    call shell(cmd//' '//fragment//' > '//shell_quote(base//'.out')// &
               ' 2> '//shell_quote(base//'.err'), code)
  end subroutine run_case

  subroutine write_text(path, text)
    character(len=*), intent(in) :: path, text
    integer :: u
    open (newunit=u, file=path, status='replace', action='write')
    write (u, '(A)') text
    close (u)
  end subroutine write_text

  subroutine write_ints(path, a, b)
    character(len=*), intent(in) :: path
    integer, intent(in) :: a, b
    integer :: u
    open (newunit=u, file=path, status='replace', action='write')
    write (u, '(I0,1X,I0)') a, b
    close (u)
  end subroutine write_ints

  subroutine read_ints(path, a, b, ok)
    character(len=*), intent(in) :: path
    integer, intent(out) :: a, b
    logical, intent(out) :: ok
    integer :: u, ios
    a = 0
    b = 0
    open (newunit=u, file=path, status='old', action='read', iostat=ios)
    ok = ios == 0
    if (.not. ok) return
    read (u, *, iostat=ios) a, b
    ok = ios == 0
    close (u)
  end subroutine read_ints

  subroutine read_line(path, line, ok)
    character(len=*), intent(in) :: path
    character(len=line_len), intent(out) :: line
    logical, intent(out) :: ok
    integer :: u, ios
    line = ''
    open (newunit=u, file=path, status='old', action='read', iostat=ios)
    ok = ios == 0
    if (.not. ok) return
    read (u, '(A)', iostat=ios) line
    close (u)
  end subroutine read_line

  ! Whole file as bytes. A missing file reads as empty with ok = .false.
  subroutine slurp(path, bytes, ok)
    character(len=*), intent(in) :: path
    character(len=:), allocatable, intent(out) :: bytes
    logical, intent(out) :: ok
    integer :: u, ios, n
    open (newunit=u, file=path, status='old', action='read', &
          access='stream', form='unformatted', iostat=ios)
    ok = ios == 0
    if (.not. ok) then
      bytes = ''
      return
    end if
    inquire (unit=u, size=n)
    allocate (character(len=n) :: bytes)
    if (n > 0) read (u, iostat=ios) bytes
    ok = ios == 0
    close (u)
  end subroutine slurp

  subroutine record(status)
    integer, intent(out) :: status
    character(len=line_len) :: line
    integer :: u, ios, n, code
    character(len=:), allocatable :: base

    status = 0
    open (newunit=u, file=cases_file, status='old', action='read', iostat=ios)
    if (ios /= 0) then
      write (0, '(A)') 'fortran-anything: cannot read cases file "'//cases_file//'"'
      status = 1
      return
    end if

    call shell('rm -rf '//shell_quote(dir//'/recording')//' '//shell_quote(dir//'/report')// &
               ' && mkdir -p '//shell_quote(dir//'/recording'), code)
    if (code /= 0) then
      write (0, '(A)') 'fortran-anything: cannot create "'//dir//'"'
      status = 1
      return
    end if

    n = 0
    do
      read (u, '(A)', iostat=ios) line
      if (ios /= 0) exit
      line = adjustl(line)
      if (len_trim(line) == 0) cycle
      if (line(1:1) == '#') cycle
      n = n + 1
      base = case_path('recording', n, 'x')
      base = base(1:len(base) - 2)
      call write_text(base//'.case', trim(line))
      call run_case(command, trim(line), base, code)
      call write_ints(base//'.code', code, 0)
    end do
    close (u)

    call write_ints(dir//'/count', n, 0)
    if (n == 0) then
      write (0, '(A)') 'fortran-anything: no cases in "'//cases_file//'"'
      status = 1
      return
    end if
    write (*, '(A,I0,A)') 'recorded ', n, ' cases from the original'
  end subroutine record

  subroutine replay(status)
    integer, intent(out) :: status
    character(len=line_len) :: line
    character(len=:), allocatable :: rec, rep, want, got
    integer :: n, i, code, want_code, unused, matched
    logical :: ok, ok_want, ok_got, same

    status = 0
    call read_ints(dir//'/count', n, unused, ok)
    if (.not. ok .or. n < 1) then
      write (0, '(A)') 'fortran-anything: no recording in "'//dir//'", run record first'
      status = 1
      return
    end if
    call shell('rm -rf '//shell_quote(dir//'/replay')//' && mkdir -p '// &
               shell_quote(dir//'/replay'), code)

    matched = 0
    do i = 1, n
      rec = case_path('recording', i, 'x')
      rec = rec(1:len(rec) - 2)
      rep = case_path('replay', i, 'x')
      rep = rep(1:len(rep) - 2)

      call read_line(rec//'.case', line, ok)
      call read_ints(rec//'.code', want_code, unused, ok_want)
      call run_case(command, trim(line), rep, code)
      call slurp(rec//'.out', want, ok_want)
      call slurp(rep//'.out', got, ok_got)

      same = ok .and. ok_want .and. ok_got .and. code == want_code
      if (same) same = len(want) == len(got)
      if (same) same = want == got

      if (same) then
        matched = matched + 1
        write (*, '(A,I4.4,2X,A)') 'match     ', i, trim(line)
      else
        write (*, '(A,I4.4,2X,A)') 'MISMATCH  ', i, trim(line)
        if (code /= want_code) then
          write (*, '(A,I0,A,I0)') '            exit code: original ', want_code, ', fortran ', code
        else
          write (*, '(A)') '            stdout differs: '//rec//'.out vs '//rep//'.out'
        end if
      end if
    end do

    call write_ints(dir//'/report', matched, n)
    write (*, '(I0,A,I0,A)') matched, ' of ', n, ' recorded cases match'
    if (matched /= n) status = 1
  end subroutine replay

  subroutine gate(status)
    integer, intent(out) :: status
    integer :: matched, n
    logical :: ok

    status = 1
    call read_ints(dir//'/report', matched, n, ok)
    if (.not. ok) then
      write (*, '(A)') 'gate: closed, no diff has been run against the current recording'
    else if (n < 1 .or. matched /= n) then
      write (*, '(A,I0,A,I0,A)') 'gate: closed, ', matched, ' of ', n, ' cases match'
    else
      write (*, '(A,I0,A)') 'gate: open, all ', n, ' cases match. Ship the Fortran.'
      status = 0
    end if
  end subroutine gate

end program fortran_anything
