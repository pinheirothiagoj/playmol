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
!            Federal University of Rio de Janeiro

program playmol
use mPlaymol
use mGlobal
implicit none
integer :: i, inp
character(sl) :: infile
type(tPlaymol) :: System
if (iargc() == 0) call error( "Usage: playmol <file-1> <file-2> ..." )
call init_log( file = "playmol.log" )
do i = 1, iargc()
  call getarg( i, infile )
  open( newunit = inp, file = infile, status = "old" )
  write(*,'("Reading file ",A,"...")') trim(infile)
  call System % Read( inp )
  close(inp)
end do
call stop_log
end program playmol
