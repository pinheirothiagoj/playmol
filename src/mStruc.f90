!   This file is part of Playmol.
!
!    Playmol is free software: you can redistribute it and/or modify
!    it under the terms of the GNU General Public License as published by
!    the Free Software Foundation, either version 3 of the License, or
!    (at your option) any later version.
!
!    Playmol is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!    GNU General Public License for more details.
!
!    You should have received a copy of the GNU General Public License
!    along with Playmol. If not, see <http://www.gnu.org/licenses/>.
!
!    Author: Charlles R. A. Abreu (abreu at eq.ufrj.br)
!            Applied Thermodynamics and Molecular Simulation
!            Federal University of Rio de Janeiro, Brazil

module mStruc

use mGlobal
use mString

implicit none

type Struc
  character(sl), allocatable :: id(:)
  character(sl)              :: params
  type(Struc), pointer       :: next => null()
  contains
    procedure :: init => Struc_init
    procedure :: match_id => Struc_match_id
end type Struc

type StrucList
  character(sl)        :: name = ""
  integer              :: number = 0
  character(sl)        :: prefix = ""
  logical              :: two_way = .true.
  type(Struc), pointer :: first => null()
  type(Struc), pointer :: last  => null()
  contains
    procedure :: add => StrucList_add
    procedure :: search => StrucList_search
    procedure :: member => StrucList_member
    procedure :: parameters => StrucList_parameters
    procedure :: index => StrucList_index
    procedure :: find => StrucList_find
    procedure :: count => StrucList_count
    procedure :: print => StrucList_print
    procedure :: destroy => StrucList_destroy
end type StrucList

contains

  !=================================================================================================

  subroutine Struc_init( me, narg, arg, number )
    class(Struc), intent(out) :: me
    integer,      intent(in)  :: narg
    character(*), intent(in)  :: arg(:)
    integer,      intent(in)  :: number
    allocate( me % id(number) )
    me % id = arg(1:number)
    me % params = join( arg(number+1:narg) )
  end subroutine Struc_init

  !=================================================================================================

  function Struc_match_id( me, id, two_way ) result( match )
    class(Struc),  intent(in) :: me
    character(sl), intent(in) :: id(:)
    logical,       intent(in) :: two_way
    logical                   :: match
    match = all(match_str( me % id, id ))
    if (two_way) match = match .or. all(match_str( me % id, id(size(id):1:-1) ))
  end function Struc_match_id

  !=================================================================================================

  subroutine StrucList_add( me, narg, arg, list, repeatable )
    class(StrucList),           intent(inout) :: me
    integer,                    intent(in)    :: narg
    character(*),               intent(inout) :: arg(:)
    class(StrucList), optional, intent(in)    :: list
    logical,          optional, intent(in)    :: repeatable
    integer :: i, n
    logical :: repeat
    type(Struc), pointer :: ptr
    n = me % number
    if (narg < n) call error( "invalid", me%name, "definition" )

    if (present(list)) then
      forall (i=1:n) arg(i) = trim(list % prefix) // arg(i)
      do i = 1, n
        if (.not. list % find(arg(i:i))) then
          call error( "undefined", list%name, arg(i), "in", me%name, "definition" )
        end if
      end do
    else
      forall (i=1:n) arg(i) = trim(me % prefix) // arg(i)
    end if
    forall (i=n+1:narg) arg(i) = arg(i)

    call me % search( arg(1:n), ptr )
    if (associated(ptr)) then
      if (all(ptr%id == arg(1:n))) then
        repeat = present(repeatable)
        if (repeat) repeat = repeatable
        if (.not.repeat) call error( "repeated", me%name, join( arg(1:n) ) )
      else
        call error( "ambiguous definition of", me%name, join( arg(1:n) ) )
      end if
    end if

    if (associated(me % last)) then
      allocate( me % last % next )
      me % last => me % last % next
    else
      allocate( me % last )
      me % first => me % last
    end if
    call writeln( "Adding ", me%name, join(arg(1:n)), advance = .false. )
    call me % last % init( narg, arg, me % number )
    if (me % last % params /= "") then
      call writeln( " with parameters", me % last % params )
    else
      call end_line
    end if
  end subroutine StrucList_add

  !=================================================================================================

  subroutine StrucList_search( me, id, ptr, index )
    class(StrucList),     intent(in)            :: me
    character(*),         intent(in)            :: id(:)
    type(Struc), pointer, intent(out), optional :: ptr
    integer,              intent(out), optional :: index
    logical :: found
    integer :: i
    type(Struc), pointer :: current
    found = .false.
    current => me % first
    i = 0
    do while (associated(current).and.(.not.found))
      i = i + 1
      found = current % match_id( id, me % two_way )
      if (.not.found) current => current % next
    end do
    if (found) then
      if (present(index)) index = i
      if (present(ptr)) ptr => current
    else
      if (present(index)) index = 0
      if (present(ptr)) ptr => null()
    end if
  end subroutine StrucList_search

  !=================================================================================================

  function StrucList_member( me, id ) result( member )
    class(StrucList), intent(in) :: me
    character(*),     intent(in) :: id(:)
    type(Struc), pointer         :: member
    call me % search( id, member )
  end function StrucList_member

  !=================================================================================================

  function StrucList_parameters( me, id ) result( params )
    class(StrucList), intent(in) :: me
    character(*),     intent(in) :: id(:)
    character(sl)                :: params
    type(Struc), pointer :: ptr
    call me % search( id, ptr )
    if (associated(ptr)) then
      params = ptr % params
    else
      params = ""
    end if
  end function StrucList_parameters

  !=================================================================================================

  function StrucList_find( me, id ) result( found )
    class(StrucList), intent(in) :: me
    character(*),     intent(in) :: id(:)
    logical                      :: found
    type(Struc), pointer :: ptr
    call me % search( id, ptr )
    found = associated( ptr )
  end function StrucList_find

  !=================================================================================================

  function StrucList_index( me, id ) result( index )
    class(StrucList), intent(in) :: me
    character(*),     intent(in) :: id(:)
    integer                      :: index
    call me % search( id, index = index )
  end function StrucList_index

  !=================================================================================================

  function StrucList_count( me ) result( N )
    class(StrucList), intent(in) :: me
    integer                      :: N
    type(Struc), pointer :: current
    current => me % first
    N = 0
    do while (associated(current))
      N = N + 1
      current => current % next
    end do
  end function StrucList_count

  !=================================================================================================

  subroutine StrucList_print( me, unit, comment )
    class(StrucList), intent(in)           :: me
    integer,          intent(in)           :: unit
    logical,          intent(in), optional :: comment
    type(Struc), pointer :: current
    character(sl) :: name
    name = me % name
    if (present(comment)) then
      if (comment) name = "# "//trim(me % name)
    end if
    current => me % first
    do while (associated(current))
      write(unit,'(A,X,A,X,A)') trim(name), trim(join(current%id)), trim(current%params)
      current => current % next
    end do
  end subroutine StrucList_print

  !=================================================================================================

  subroutine StrucList_destroy( me )
    class(StrucList), intent(inout) :: me
    type(Struc), pointer :: current, aux
    current => me % first
    do while (associated(current))
      aux => current
      current => current % next
      call writeln( "Deleting ", me%name, join(aux % id) )
      deallocate(aux)
    end do
    me % first => null()
    me % last => null()
  end subroutine StrucList_destroy

  !=================================================================================================

end module mStruc
