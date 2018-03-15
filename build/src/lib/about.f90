    !------------------------------------------------------------------------------
    !        IST/MARETEC, Water Modelling Group, Mohid modelling system
    !------------------------------------------------------------------------------
    !
    ! TITLE         : Mohid Model
    ! PROJECT       : Mohid Lagrangian Tracer
    ! MODULE        : about
    ! URL           : http://www.mohid.com
    ! AFFILIATION   : IST/MARETEC, Marine Modelling Group
    ! DATE          : Feb 2018
    ! REVISION      : Canelas 0.1
    !> @author
    !> Ricardo Birjukovs Canelas
    !
    ! DESCRIPTION:
    !> Module to print version, licence, preambles.
    !------------------------------------------------------------------------------

    module about

    use commom_modules

    implicit none
    private

    !Public access procedures
    public :: PrintLicPreamble

    !version control
    type(string) :: version
    type(string) :: author
    type(string) :: date
    
    contains

    !---------------------------------------------------------------------------
    !> @Ricardo Birjukovs Canelas - MARETEC
    ! Routine Author Name and Affiliation.
    !
    !> @brief
    !> Public licence and preamble printer routine.
    !---------------------------------------------------------------------------
    subroutine PrintLicPreamble
    implicit none
    type(string) :: outext
    
    version  ="v0.0.1"
    author   ="R. Birjukovs Canelas"
    date     ="15-03-2018"

    outext = ' <MOHIDLagrangian> Copyright (C) 2018 by'//new_line('a')//&
        '  R. Birjukovs Canelas'//new_line('a')//&
        ''//new_line('a')//&
        '  MARETEC - Research Centre for Marine, Environment and Technology'//new_line('a')//&
        ''//new_line('a')//&
        '  MOHIDLagrangian is free software: you can redistribute it and/or'//new_line('a')//&
        '  modify it under the terms of the GNU General Public License as'//new_line('a')//&
        '  published by the Free Software Foundation, either version 3 of'//new_line('a')//&
        '  the License, or (at your option) any later version.'//new_line('a')//&
        ''//new_line('a')//&
        '  MOHIDLagrangian is distributed WITHOUT ANY WARRANTY; without even'//new_line('a')//&
        '  the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR'//new_line('a')//&
        '  PURPOSE. See the GNU General Public License for more details.'//new_line('a')//&
        ''//new_line('a')//&
        '  You should have received a copy of the GNU General Public License,'//new_line('a')//&
        '  along with MOHIDLagrangian. If not, see <http://www.gnu.org/licenses/>.,'//new_line('a')//&
        ''//new_line('a')//&
        ''//new_line('a')//&
        'MOHIDLagrangian '//version//' ('//author//') ('//date//')'//new_line('a')//&
        '====================================================================='

    call ToLog(outext,.false.)

    end subroutine

    end module about