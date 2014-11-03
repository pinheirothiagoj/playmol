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

module mPackmol

use mGlobal
use mStruc
use mBox

implicit none

character(sl), parameter :: stdout_name = "/dev/stdout"

integer  :: seed = 1234
integer  :: nloops = 50
real(rb) :: change = 0.95_rb
real(rb) :: tolerance = 1.0_rb

interface
  subroutine packmol( inp, stat )
    integer, intent(in)  :: inp
    integer, intent(out) :: stat
  end subroutine packmol 
end interface

contains

  !=================================================================================================

  subroutine packmol_file_names( inputfile, molfile, mixfile, random_names )
    character(sl), intent(out) :: inputfile, molfile(:), mixfile
    logical,       intent(in)  :: random_names
    integer :: i
    type(rng) :: random
    if (random_names) then
      call random % init( seed )
      inputfile = "0"//trim(random % letters(10))//".inp"
      do i = 1, size(molfile)
        molfile(i) = "0"//trim(random % letters(10))//".xyz"
      end do
      mixfile = "0"//trim(random % letters(10))//".xyz"
    else
      inputfile = "packmol.inp"
      do i = 1, size(molfile)
        molfile(i) = "molecule_"//trim(int2str(i))//".xyz"
      end do
      mixfile = "packmol_output.xyz"
    end if
  end subroutine packmol_file_names

  !=================================================================================================

  subroutine packmol_xyz_files( lpack, lmol, lcoord, natoms, molfile, print )

    type(StrucList), intent(in)  :: lpack, lmol, lcoord
    integer,         intent(in)  :: natoms(:)
    character(sl),   intent(out) :: molfile(:)
    logical,         intent(in)  :: print

    integer :: i, ifile, nfiles, imol, unit, iatom, pos, minpos, narg
    type(Struc), pointer :: ptr, coord
    integer, allocatable :: molecule(:)
    character(sl) :: arg(4)

    ptr => lpack % first
    nfiles = 0
    allocate( molecule(lpack % count()) )
    do while (associated(ptr))
      call split( ptr % params, narg, arg )
      imol = str2int(arg(1))
      if (all(molecule(1:nfiles) /= imol)) then
        nfiles = nfiles + 1
        molecule(nfiles) = imol
      end if
      ptr => ptr % next
    end do

    do ifile = 1, nfiles
      imol = molecule(ifile)

      if (print) call writeln( "Saving coordinate file", molfile(ifile) )

      i = 0
      minpos = lmol % count()
      ptr => lmol % first
      do while (associated(ptr).and.(i < natoms(imol)))
        if (str2int(ptr % params) == imol) then
          i = i + 1
          pos = lcoord % index( ptr % id )
          if (pos == 0) call error( "no coordinates for molecule", int2str(imol) )
          minpos = min(pos,minpos)
        end if
        ptr => ptr % next
      end do

      open( newunit = unit, file = molfile(ifile), status = "replace" )
      write(unit,'(A)') trim(int2str(natoms(imol)))
      write(unit,'("# Generated by playmol")')
      coord => lcoord % first
      do i = 2, minpos
        coord => coord % next
      end do
      do iatom = 1, natoms(imol)
        write(unit,'(A)') trim(coord % id(1))//" "//trim(coord % params)
        coord => coord % next
      end do
      close(unit)
    end do

  end subroutine packmol_xyz_files

  !=================================================================================================

  subroutine packmol_input_file( lpack, seed, tol, Lbox, inputfile, mixfile, molfile )
    type(StrucList), intent(in) :: lpack
    integer,         intent(in) :: seed
    real(rb),        intent(in) :: tol, Lbox(3)
    character(sl),   intent(in) :: inputfile, mixfile, molfile(:)

    integer :: unit, imol, narg
    character(sl) :: box_limits, arg(4)
    type(Struc), pointer :: ptr

    ! Define box limits:
    box_limits = join(real2str([-0.5_rb*(Lbox - tol), +0.5_rb*(Lbox - tol)]))

    ! Create packmol input script:
    open( newunit = unit, file = inputfile, status = "replace" )
    write(unit,'("# Generated by playmol",/)')
    write(unit,'("tolerance ",A)') trim(real2str(tol))
    write(unit,'("filetype xyz")')
    write(unit,'("seed ",A)') trim(int2str(seed))
    write(unit,'("nloop ",A)') trim(int2str(nloops))
    write(unit,'("output ",A)') trim(mixfile)
    ptr => lpack % first
    do while (associated(ptr))
      call split( ptr % params, narg, arg )
      imol = str2int(arg(1))
      write(unit,'(/,"structure ",A)') trim(molfile(imol))
      select case (ptr % id(1))
        case ("move","fix")
          write(unit,'("  number 1")')
          if (ptr % id(1) == "fix") write(unit,'("  center")')
          write(unit,'("  fixed ",A," 0.0 0.0 0.0")') trim(join(arg(2:4)))
        case ("copy","pack")
          write(unit,'("  number ",A)') trim(arg(2))
          write(unit,'("  inside box ",A)') trim(box_limits)
          if (ptr % id(1) == "copy") then
            write(unit,'("  constrain_rotation x 0.0 0.0")')
            write(unit,'("  constrain_rotation y 0.0 0.0")')
            write(unit,'("  constrain_rotation z 0.0 0.0")')
          end if
      end select
      write(unit,'("end structure")')
      ptr => ptr % next
    end do
    close(unit)

  end subroutine packmol_input_file

  !=================================================================================================

  function packmol_total_mass( lpack, molmass ) result( mass )
    type(StrucList), intent(in) :: lpack
    real(rb),        intent(in) :: molmass(:)
    real(rb)                    :: mass

    type(Struc), pointer :: ptr
    integer :: imol, narg, nmol
    character(sl) :: arg(4)

    mass = 0.0_rb
    ptr => lpack % first
    do while (associated(ptr))
      call split( ptr % params, narg, arg )
      imol = str2int( arg(1) )
      select case (ptr % id(1))
        case ("move","fix")
          mass = mass + molmass(imol)
        case ("copy","pack")
          nmol = str2int(arg(2))
          mass = mass + nmol*molmass(imol)
      end select
      ptr => ptr % next
    end do

  end function packmol_total_mass

  !=================================================================================================

  subroutine run_packmol( lpack, lmol, lcoord, nmol, natoms, Lbox, seed, tol, action )
    use iso_fortran_env, only : screen => output_unit
    type(StrucList), intent(inout) :: lpack, lmol, lcoord
    integer,         intent(inout) :: nmol
    integer,         intent(in)    :: natoms(nmol), seed
    real(rb),        intent(in)    :: Lbox(3), tol
    character(sl),   intent(in)    :: action

    integer :: stat, unit
    real(rb) :: trytol
    logical :: redirect
    character(sl) :: molfile(nmol), mixfile, inputfile

    open( newunit = unit, file = stdout_name, status = "old", iostat = stat )
    redirect = stat == 0
    if (redirect) close( unit )

    call writeln( "Packmol invoked with action <"//trim(action)//">" )

    call packmol_file_names( inputfile, molfile, mixfile, action /= "setup" )
    call packmol_xyz_files( lpack, lmol, lcoord, natoms, molfile, action == "setup" )

    select case (action)

      case ("execute")

        call execute_packmol( tol, stat )
        if (stat == 0) then
          call retrieve_coordinates( mixfile )
          call delete_files( [inputfile, mixfile, molfile] )
        else
          call delete_files( [inputfile, mixfile, trim(mixfile)//"_FORCED", molfile] )
          call error( "Packmol did not converge! See file packmol.log for additional info.")
        end if

      case ("persist")

        stat = 1
        trytol = tol
        do while (stat /= 0)
          call execute_packmol( trytol, stat )
          if (stat /= 0) trytol = change * trytol
        end do
        call retrieve_coordinates( mixfile )
        call delete_files( [inputfile, mixfile, trim(mixfile)//"_FORCED", molfile] )
        call writeln( "Packmol converged with tolerance =", real2str(trytol) )

      case ("setup")

        call writeln( "Saving packmol input file", inputfile )
        call packmol_input_file( lpack, seed, tol, Lbox, inputfile, mixfile, molfile )

    end select

    call lpack % destroy

    contains
      !---------------------------------------------------------------------------------------------
      subroutine execute_packmol( tol, stat )
        real(rb), intent(in)  :: tol
        integer,  intent(out) :: stat
        integer :: inp
        call packmol_input_file( lpack, seed, tol, Lbox, inputfile, mixfile, molfile )
        open( newunit = inp, file = inputfile, status = "old" )
        call writeln( "Trying Packmol with tolerance", trim(real2str(tol))//".", &
                      "Please wait..." )
        if (redirect) open( unit = screen , file = "packmol.log", status = "replace" )
        call packmol( inp, stat )
        if (redirect) then
          close( screen )
          open( unit = screen , file = stdout_name, status = "old" )
        end if
        close(inp)
      end subroutine execute_packmol
      !---------------------------------------------------------------------------------------------
      subroutine retrieve_coordinates( mixfile )
        character(*), intent(in) :: mixfile
        integer :: mix, narg, natoms, iatom
        character(sl) :: line, arg(4)
        call lcoord % destroy
        open( newunit = mix, file = mixfile, status = "old" )
        read(mix,'(I12,/)') natoms
        do iatom = 1, natoms
          read(mix,'(A'//csl//')') line
          call split( line, narg, arg )
          call lcoord % add( narg, arg, repeatable = .true. )
        end do
        close( mix, status = "delete" )
      end subroutine retrieve_coordinates
      !---------------------------------------------------------------------------------------------
  end subroutine run_packmol

  !=================================================================================================

end module mPackmol
