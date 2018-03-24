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

! TODO: Check whether it is possible to repeat proper dihedral types for the same set of atom types
! TODO: Implement improper dihedrals (check order conformity with LAMMPS)
! TODO: Implement non-bonded models

  subroutine tPlaymol_write_openmm( me, unit, keywords )
    class(tPlaymol), intent(inout)        :: me
    integer,         intent(in)           :: unit
    character(*),    intent(in)           :: keywords

    integer :: imol, ntotal
    real(rb) :: length, energy, angle
    logical :: guess, water(me % molecules % N)

    integer, allocatable :: natoms(:)
    character(sl), allocatable :: atom(:), atom_type(:), raw_atom(:), charge(:), element(:), mass(:)

    call process( keywords )

    natoms = me % molecules % number_of_atoms()
    ntotal = sum(natoms)
    allocate( atom(ntotal), &
              atom_type(ntotal), &
              raw_atom(ntotal), &
              charge(ntotal), &
              element(ntotal), &
              mass(ntotal) )

    block
      integer :: i, n, mol(ntotal)
      type(Struc), pointer :: current
      n = 0
      current => me % molecules % list % first
      do while (associated(current))
        imol = str2int(current % params)
        if (natoms(imol) > 0) then
          n = n + 1
          mol(n) = imol
          atom(n) = current % id(1)
        end if
        current => current % next
      end do
      atom = atom(sorted(mol))
      do i = 1, ntotal
        atom_type(i) = me % atom_list % parameters( atom(i:i) )
        raw_atom(i) = me % raw_atom_list % parameters( atom(i:i) )
        charge(i) = me % charge_list % parameters( atom(i:i), default = "0" )
        call me % element_and_mass( atom_type(i), element(i), mass(i) )
        if (guess.and.(element(i) == "UA")) element(i) = element_guess( mass(i) )
      end do
    end block

    write(unit,'("<ForceField>")')
    call write_atom_types()

    write(unit,'("  <Residues>")')
    water = me % is_water()
    do imol = 1, me % molecules % N
      call write_residue( imol )
    end do
    write(unit,'("  </Residues>")')

    write(unit,'(2X,"<HarmonicBondForce>")')
    call write_bond_types()
    write(unit,'(2X,"</HarmonicBondForce>")')

    write(unit,'(2X,"<HarmonicAngleForce>")')
    call write_angle_types()
    write(unit,'(2X,"</HarmonicAngleForce>")')

    write(unit,'(2X,"<PeriodicTorsionForce>")')
    call write_dihedral_types()
    write(unit,'(2X,"</PeriodicTorsionForce>")')

    write(unit,'("</ForceField>")')

    contains

      !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

      subroutine process( keywords )
        character(*), intent(in) :: keywords
        integer :: i, narg
        character(sl) :: keyword, value, arg(40)
        call split( keywords, narg, arg)
        if (mod(narg, 2) == 1) call error( "invalid write openmm command" )
        do i = 1, narg/2
          keyword = arg(2*i-1)
          value = arg(2*i)
          select case (keyword)
            case ("length")
              length = str2real(value)
            case ("energy")
              energy = str2real(value)
            case ("angle")
              angle = str2real(value)
            case ("elements")
              if (.not.any(value == ["yes", "no "])) call error( "invalid write openmm command" )
              guess = (value == "yes")
            case default
              call error( "invalid write openmm command" )
          end select
        end do
      end subroutine process

      !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

      subroutine write_atom_types()
        integer :: i, n
        character(sl) :: itype, local_list(ntotal)
        character(sl), parameter :: p3(3) = [character(sl) :: "name", "class", "mass"], &
                                    p4(4) = [character(sl) :: "name", "class", "element", "mass"]

        write(unit,'(2X,"<AtomTypes>")')
        n = 0
        do i = 1, ntotal
          itype = atom_type(i)
          if (all(local_list(1:n) /= itype)) then
            n = n + 1
            local_list(n) = itype
            if ((element(i) == "EP").or.(element(i) == "UA")) then
              call write_items(4, "Type", p3, [itype, itype, mass(i)])
            else
              call write_items(4, "Type", p4, [itype, itype, element(i), mass(i)])
            end if
          end if
        end do
        write(unit,'(2X,"</AtomTypes>")')
      end subroutine write_atom_types

      !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

      subroutine write_residue( imol )
        integer, intent(in) :: imol

        integer :: i, first, last
        character(sl) :: resname
        integer, allocatable :: indx(:), pos(:)
        type(Struc), pointer :: current

        character(sl), parameter :: pa(3) = [character(sl) :: "name", "type", "charge"], &
                                    pb(2) = [character(sl) :: "atomName1", "atomName2"]

        last = sum(natoms(1:imol))
        first = last - natoms(imol) + 1

        if (water(imol)) then
          resname = "HOH"
        else
          resname = letterCode( imol - count(water(1:imol-1)) )
        end if
        write(unit,'(4X,"<Residue ",A,">")') trim(item("name", resname))

        do i = first, last
          call write_items(6, "Atom", pa, [raw_atom(i), atom_type(i), charge(i)])
        end do

        ! Virtual sites:
        do i = first, last
          if (element(i) == "EP") call virtual_site( i )
        end do

        ! Bonds:
        indx = pack([(i,i=first,last)], element(first:last) /= "EP")
        current => me % bond_list % first
        do while (associated(current))
          pos = pack(indx, (atom(indx) == current%id(1)).or.(atom(indx) == current%id(2)))
          if (size(pos) == 2) then
            call write_items(6, "Bond", pb, raw_atom(pos))
          end if
          current => current % next
        end do

        write(unit,'(4X,"</Residue>")')
      end subroutine write_residue

      !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

      subroutine virtual_site( i )
        integer, intent(in) :: i

        real(rb), parameter :: tol = 1.0E-4_rb

        integer :: k, n
        character(sl) :: string
        integer :: partner(3)
        real(rb) :: a(3,3), b(3), w(3), axis(3,3)
        character(sl) :: xyz(3), average(3)
        integer, allocatable :: pos(:)
        character(sl), allocatable :: properties(:), values(:)
        type(Struc), pointer :: current

        string = me % molecules % xyz % parameters( [atom(i)] )
        call split(string, k, xyz)
        b = [(str2real(xyz(k)),k=1,3)]
        n = 0
        current => me % link_list % first
        do while (associated(current).and.(n < 4))
          pos = pack([2,1], current%id == atom(i))
          if (size(pos) > 0) then
            n = n + 1
            string = me % molecules % xyz % parameters( [current%id(pos(1))] )
            call split(string, k, xyz)
            a(:,n) = [(str2real(xyz(k)),k=1,3)]
            partner(n:n) = pack([(k,k=1,size(atom))], atom == current%id(pos(1)))
          end if
          current => current % next
        end do
        if (n == 2) then
          ! Test for colinearity:
          if (colinear(a(:,1), a(:,2), b)) then
            w(1:2) = gaussian_elimination( a(1:2,1:2), b(1:2) )
            average(1:2) = [character(sl) :: "1", "2"]
          else
            call error( "VirtualSite type average2 requires colinearity")
          end if
        else if (n == 3) then
          axis(:,1) = unit_vector(a(:,1), a(:,2))
          axis(:,2) = unit_vector(a(:,1), a(:,3))
          axis(:,3) = cross_product(axis(:,1), axis(:,2))
          w = gaussian_elimination( axis, b - a(:,1) )
          if (abs(w(3)) < tol) then
            w = gaussian_elimination( a, b )
            average = [character(sl) :: "1", "2", "3"]
          else
            average = [character(sl) :: "12", "13", "Cross"]
          end if
        else
          call error( "Extra particle must be linked to 2 or 3 atoms" )
        end if
        properties = [character(sl) :: "type", "siteName", &
                      ("atomName"//int2str(k), k=1, n), ("weight"//average(k), k=1, n)]
        values = [character(sl) :: "average"//average(n), raw_atom(i), &
                  raw_atom(partner), (float2str(w(k)),k=1,3)]
        call write_items(6, "VirtualSite", properties, values)
      end subroutine virtual_site

      !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

      subroutine write_bond_types()
        integer :: narg
        real(rb) :: K, r0
        character(sl) :: arg(20)
        type(Struc), pointer :: current
!        type(StrucList) :: local_list = StrucList( "bond type", 2 )
        current => me % bond_type_list % first
        do while (associated(current))
          if (current % usable) then
            if (any(has_macros(current%id))) call error( "wildcards not permitted in bond types" )
            call split( current%params, narg, arg )
            if ((narg == 2).and.all(is_real(arg(1:2)))) then
              K = 2.0_rb*str2real(arg(1)) * energy/length**2
              r0 = str2real(arg(2)) * length
            else if (arg(1) == "harmonic") then
              K = 2.0_rb*str2real(arg(2)) * energy/length**2
              r0 = str2real(arg(3)) * length
            else if (arg(1) == "zero") then
              current => current % next
              cycle
            else
              call error( "harmonic bond model required" )
            end if
            call write_items(4, "Bond", ["type1 ", "type2 ", "length", "k     "], &
                                        [current%id, real2str([r0, K])])
          end if
          current => current % next
        end do
      end subroutine write_bond_types

      !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

      subroutine write_angle_types()
        integer :: narg
        real(rb) :: K, theta0
        character(sl) :: arg(20)
        type(Struc), pointer :: current
        current => me % angle_type_list % first
        do while (associated(current))
          if (current % usable) then
            if (any(has_macros(current%id))) call error( "wildcards not permitted in angle types" )
            call split( current%params, narg, arg )
            if ((narg == 2).and.all(is_real(arg(1:2)))) then
              K = 2.0_rb*str2real(arg(1)) * energy
              theta0 = str2real(arg(2)) * angle
            else if (arg(1) == "harmonic") then
              K = 2.0_rb*str2real(arg(2)) * energy
              theta0 = str2real(arg(3)) * angle
            else
              call error( "harmonic angle model required" )
            end if
            call write_items(4, "Angle", ["type1", "type2", "type3", "angle", "k    "], &
                                        [current%id, real2str([theta0, K])])
          end if
          current => current % next
        end do
      end subroutine write_angle_types

      !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

      subroutine write_dihedral_types()
        integer :: i, narg, n
        real(rb) :: K, phase
        character(sl) :: arg(20), atom_type(4), S
        type(Struc), pointer :: current
        current => me % dihedral_type_list % first
        do while (associated(current))
          if (current % usable) then
            do i = 1, 4
              S = current%id(i)
              if (has_macros(S)) then
                if (S /= "*") call error( "partial wildcard not permitted in dihedral types" )
                atom_type(i) = ""
              else
                atom_type(i) = S
              end if
            end do
            call split( current%params, narg, arg )
            if ((arg(1) == "harmonic").or.((narg == 3).and.all(is_real(arg(1:narg))))) then
              K = str2real(arg(2)) * energy
              n = str2int(arg(4))
              phase = 90*(1 - str2int(arg(3))) * angle
            else if ((arg(1) == "charmm").or.((narg == 4).and.all(is_real(arg(1:narg))))) then
              K = str2real(arg(2)) * energy
              n = str2int(arg(3))
              phase = str2int(arg(4)) * angle
            else
              call error( "harmonic or charmm angle model required" )
            end if
            call write_items(4, "Proper", [character(sl) :: "type1", "type2", "type3", "type4", &
                                                            "periodicity1", "phase1", "k1"],    &
                                        [atom_type, [int2str(n), real2str(phase), real2str(K)]] )
          end if
          current => current % next
        end do
      end subroutine write_dihedral_types

      !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

      subroutine write_items( ident, title, property, value )
        integer,      intent(in) :: ident
        character(*), intent(in) :: title, property(:), value(:)
        integer :: i
        write(unit,'("'//repeat(" ",ident)//'","<",A,X,A,"/>")') trim(title), &
          trim(join([(item(property(i), value(i)), i=1, size(property))]))
      end subroutine write_items

      !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

      elemental character(sl) function item( property, value )
        character(*), intent(in) :: property, value
        item = trim(property)//"="""//trim(value)//""""
      end function item

      !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

      function element_guess( mass ) result( element )
        character(sl), intent(in) :: mass
        character(sl)             :: element
        element = me%elements(minloc(abs(me%masses - str2real(mass)), dim = 1))
      end function element_guess

      !- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

  end subroutine tPlaymol_write_openmm
