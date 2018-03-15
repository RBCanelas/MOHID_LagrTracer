
    !------------------------------------------------------------------------------
    !        IST/MARETEC, Water Modelling Group, Mohid modelling system
    !------------------------------------------------------------------------------
    !
    ! TITLE         : Mohid Model
    ! PROJECT       : Mohid Lagrangian Tracer
    ! MODULE        : initialize
    ! URL           : http://www.mohid.com
    ! AFFILIATION   : IST/MARETEC, Marine Modelling Group
    ! DATE          : March 2018
    ! REVISION      : Canelas 0.1
    !> @author
    !> Ricardo Birjukovs Canelas
    !
    ! DESCRIPTION:
    !> Module with the simulation initialization related definitions and methods. Has one public access routine that is incharge of building the simulation space from input files.
    !------------------------------------------------------------------------------
    
    module initialize

    use tracer3D
    use simulation_globals
    use source_identity
    use about

    use FoX_dom
    use commom_modules

    implicit none
    private

    !Public access procedures
    public :: initMohidLagrangian

    contains    
    
    !---------------------------------------------------------------------------
    !> @Ricardo Birjukovs Canelas - MARETEC
    ! Routine Author Name and Affiliation.
    !
    !> @brief
    !> Private attribute xml parser routine. In the format <Tag att_name="att_value"
    !
    !> @param[in] xmlnode, tag, vec
    !---------------------------------------------------------------------------
    subroutine readxmlatt(xmlnode, tag, att_name, att_value)
    implicit none
    type(Node), intent(in), pointer :: xmlnode  !<Working xml node
    type(string), intent(in) :: tag             !<Tag to search in xml node
    type(string), intent(in) :: att_name        !<Atribute name to collect from tag
    type(string), intent(out) :: att_value      !<Attribute value
    
    type(string) :: outext
    character(80) :: att_value_chars
    type(NodeList), pointer :: nodeList
    type(Node), pointer :: nodedetail

    nullify(nodeList)
    nodeList => getElementsByTagname(xmlnode, tag%chars())   !searching for tags with the given name
    if (associated(nodeList)) then
        nodedetail => item(nodeList, 0)
        call extractDataAttribute(nodedetail, att_name%chars(), att_value_chars)
        att_value=trim(att_value_chars)
    else
        outext='Could not find any '//tag//' tag for xml node '//getNodeName(xmlnode)//', stoping'
        call ToLog(outext)        
        stop
    endif
    end subroutine
    
    !---------------------------------------------------------------------------
    !> @Ricardo Birjukovs Canelas - MARETEC
    ! Routine Author Name and Affiliation.
    !
    !> @brief
    !> Private vector xml parser routine. Vector must be in format <Tag x="vec%x" y="vec%y" z="vec%z" /> 
    !
    !> @param[in] xmlnode, tag, vec
    !---------------------------------------------------------------------------
    subroutine readxmlvector(xmlnode, tag, vec)
    implicit none
    type(Node), intent(in), pointer :: xmlnode  !<Working xml node
    type(string), intent(in) :: tag             !<Tag to search in xml node
    type(vector), intent(out) :: vec            !<Vector to fill with read contents

    type(string) :: outext
    type(NodeList), pointer :: nodeList
    type(Node), pointer :: nodedetail

    nullify(nodeList)
    nodeList => getElementsByTagname(xmlnode, tag%chars())   !searching for tags with the given name
    if (associated(nodeList)) then
        nodedetail => item(nodeList, 0)
        call extractDataAttribute(nodedetail, "x", vec%x)
        call extractDataAttribute(nodedetail, "y", vec%y)
        call extractDataAttribute(nodedetail, "z", vec%z)
    else
        outext='Could not find any '//tag//' tag for xml node '//getNodeName(xmlnode)//', stoping'
        call ToLog(outext)
        stop
    endif
    end subroutine

    !---------------------------------------------------------------------------
    !> @Ricardo Birjukovs Canelas - MARETEC
    ! Routine Author Name and Affiliation.
    !
    !> @brief
    !> Private geometry xml parser routine. Reads a geometry from the xml depending on the geometry type of the node
    !
    !> @param[in] source, geometry
    !---------------------------------------------------------------------------
    subroutine read_xml_geometry(source,source_detail,geometry)
    implicit none
    type(Node), intent(in), pointer :: source           !<Working xml node
    type(Node), intent(in), pointer :: source_detail    !<Working xml node details 
    
    type(string) :: outext
    class(shape), intent(inout) :: geometry
    type(string) :: tag

    select type (geometry)
    type is (shape)
        !nothing to do
    class is (box)
        tag='point'
        call readxmlvector(source,tag,geometry%pt)
        tag='size'
        call readxmlvector(source,tag,geometry%size)
    class is (point)
        tag='point'
        call readxmlvector(source,tag,geometry%pt)        
    class is (line)
        tag='pointa'
        call readxmlvector(source,tag,geometry%pt)
        tag='pointb'
        call readxmlvector(source,tag,geometry%last)
    class is (sphere)
        tag='point'
        call readxmlvector(source,tag,geometry%pt)
        call extractDataAttribute(source_detail, "radius", geometry%radius)        
    class default
        outext='read_xml_geometry: unexpected type for geometry object!'
        call ToLog(outext)
        stop
    end select

    end subroutine

    !---------------------------------------------------------------------------
    !> @Ricardo Birjukovs Canelas - MARETEC
    ! Routine Author Name and Affiliation.
    !
    !> @brief
    !> Private source definitions parser routine. Builds the tracer sources from the input xml case file.
    !
    !> @param[in] parsedxml
    !---------------------------------------------------------------------------
    subroutine init_sources(parsedxml)
    implicit none
    type(Node), intent(in), pointer :: parsedxml    !<.xml file handle

    type(string) :: outext
    type(NodeList), pointer :: sourcedefList        !< Node list for simulationdefs
    type(NodeList), pointer :: sourceList           !< Node list for sources
    type(NodeList), pointer :: sourcedetailList
    type(Node), pointer :: sourcedef
    type(Node), pointer :: source                   !< Single source block to process
    type(Node), pointer :: source_detail
    integer :: i, j, k
    !source vars
    integer :: id
    type(string) :: name, source_geometry, tag, att_name, att_val
    character(80) :: val, name_char, source_geometry_char
    real(prec) :: emitting_rate
    class(shape), allocatable :: geometry

    nullify(sourcedefList)
    nullify(sourceList)
    sourcedefList => getElementsByTagname(parsedxml, "sourcedef")       !searching for tags with the 'simulationdefs' name
    sourcedef => item(sourcedefList,0)
    sourceList => getElementsByTagname(sourcedef, "source")    

    call allocSources(getLength(sourceList))                         !allocating the source objects

    do j = 0, getLength(sourceList) - 1
        source => item(sourceList,j)        
        tag="setsource"
        att_name="id"
        call readxmlatt(source, tag, att_name, att_val)
        id=att_val%to_number(I1P)
        att_name="name"
        call readxmlatt(source, tag, att_name, name)        
        tag="set"
        att_name="emitting_rate"
        call readxmlatt(source, tag, att_name, att_val)
        val = att_val%chars()
        read(val,*)emitting_rate
        !now we need to find out the geometry of the source and read accordingly
        nullify(sourcedetailList)
        source_detail => item(getChildNodes(source),5)   !this is really ugly, but there seems to be a bug here. This effectivelly hardcodes the geometry position in the xml...
        source_geometry = getNodeName(source_detail)
        select case (source_geometry%chars())
        case ('point')
            allocate(point::geometry)
        case ('sphere')
            allocate(sphere::geometry)            
        case ('box')
            allocate(box::geometry)
        case ('line')
            allocate(line::geometry)
        case default
            outext='init_sources: unexpected type for geometry object!'
            call ToLog(outext)
            stop
        end select
        call read_xml_geometry(source,source_detail,geometry)

        !initializing Source j
        call initSource(j+1,id,name,emitting_rate,source_geometry,geometry)

        deallocate(geometry)
    enddo

    return
    end subroutine

    !---------------------------------------------------------------------------
    !> @Ricardo Birjukovs Canelas - MARETEC
    ! Routine Author Name and Affiliation.
    !
    !> @brief
    !> Private simulation definitions parser routine. Builds the simulation geometric space from the input xml case file.
    !
    !> @param[in] parsedxml
    !---------------------------------------------------------------------------
    subroutine init_simdefs(parsedxml)
    implicit none
    type(Node), intent(in), pointer :: parsedxml    !<.xml file handle

    type(NodeList), pointer :: defsList       !< Node list for simdefs
    type(Node), pointer :: simdefs            !< Single simdefs block to process
    type(string) :: outext
    real(prec) :: i
    type(string) :: pts(2), tag, att_name, att_val
    type(vector) :: coords
    
    outext='-->Reading case simulation definitions'
    call ToLog(outext,.false.)
    
    nullify(defsList)
    defsList => getElementsByTagname(parsedxml, "simulationdefs")       !searching for nodes with the 'simulationdefs' name
    simdefs => item(defsList,0)
    tag="resolution"
    att_name="dp"
    call readxmlatt(simdefs, tag, att_name, att_val)    
    call setSimDp(att_val)    

    pts=(/ 'pointmin', 'pointmax'/) !strings to search for
    do i=1, size(pts)
        call readxmlvector(simdefs, pts(i), coords)
        call setSimBounds(pts(i), coords)        
    enddo
    call printSimDefs
    
    return
    end subroutine

    !---------------------------------------------------------------------------
    !> @Ricardo Birjukovs Canelas - MARETEC
    ! Routine Author Name and Affiliation.
    !
    !> @brief
    !> Private case constant parser routine. Builds the simulation parametric space from the input xml case file.
    !
    !> @param[in] parsedxml
    !---------------------------------------------------------------------------
    subroutine init_caseconstants(parsedxml)
    implicit none
    type(Node), intent(in), pointer :: parsedxml    !<.xml file handle

    type(NodeList), pointer :: constsList       !< Node list for constants
    type(Node), pointer :: constants            !< Single constants block to process
    type(string) :: outext
    type(string) :: tag, att_name, att_val
    type(vector) :: coords
    
    outext='-->Reading case constants'
    call ToLog(outext,.false.)
       
    nullify(constsList)
    constsList => getElementsByTagname(parsedxml, "constantsdef")       !searching for nodes with the 'constantsdef' name
    constants => item(constsList,0)    
    tag="Gravity"
    call readxmlvector(constants, tag, coords)
    call setSimGravity(coords)    
    tag="Rho_ref"
    att_name="value"
    call readxmlatt(constants, tag, att_name, att_val)    
    call setSimRho(att_val) 
    
    return
    end subroutine

    !---------------------------------------------------------------------------
    !> @Ricardo Birjukovs Canelas - MARETEC
    ! Routine Author Name and Affiliation.
    !
    !> @brief
    !> Private parameter parser routine. Builds the simulation parametric space from the input xml case file.
    !
    !> @param[in] parsedxml
    !---------------------------------------------------------------------------
    subroutine init_parameters(parsedxml)
    implicit none
    type(Node), intent(in), pointer :: parsedxml    !<.xml file handle

    type(string) :: outext
    type(NodeList), pointer :: parameterList, parametersList        !< Node list for parameters
    type(Node), pointer :: parmt, parameters                    !< Single parameter block to process
    integer :: i
    type(string) :: parmkey, parmvalue
    character(80) :: parmkey_char, parmvalue_char
    
    outext='-->Reading case parameters'
    call ToLog(outext,.false.)    

    nullify(parameterList)
    nullify(parametersList)
    parametersList => getElementsByTagname(parsedxml, "parameters")
    parameters => item(parametersList,0)
    parameterList => getElementsByTagname(parameters, "parameter")       !searching for tags with the 'parameter' name
    if (associated(parameterList)) then                                !checking if the list is not empty
        do i = 0, getLength(parameterList) - 1                          !extracting parameter tags one by one
            parmt => item(parameterList, i)
            call extractDataAttribute(parmt, "key", parmkey_char)       !name of the parameter
            call extractDataAttribute(parmt, "value", parmvalue_char)   !value of the parameter
            parmkey=trim(parmkey_char)
            parmvalue=trim(parmvalue_char)
            call setSimParameter(parmkey,parmvalue)
        enddo
    else
        outext='Could not find any parameter tag in input file, stopping'
        call ToLog(outext)        
        stop
    endif
    
    call printSimParameters
    
    return
    end subroutine


    !---------------------------------------------------------------------------
    !> @Ricardo Birjukovs Canelas - MARETEC
    ! Routine Author Name and Affiliation.
    !
    !> @brief
    !> Public xml parser routine. Builds the simulation space from the input xml case file.
    !
    !> @param[in] xmlfilename
    !---------------------------------------------------------------------------
    subroutine initMohidLagrangian(xmlfilename)
    implicit none
    type(string), intent(in) :: xmlfilename         !< .xml file name

    !local vars
    type(string) :: outext
    type(Node), pointer :: xmldoc                   !< .xml file handle
    integer :: i
    
    call PrintLicPreamble
    
    !check if log file was opened - if not stop here
    if (Log_unit==0) then
        outext='->Logger initialized'
        call ToLog(outext)
    else
        stop 'Logger has not been initialized, stopping'
    end if    

    xmldoc => parseFile(xmlfilename%chars(), iostat=i)
    if (i==0) then
        outext='->Reading case definition from '//xmlfilename
        call ToLog(outext)
    else
        outext='Could not open '//xmlfilename//' input file, give me at least that!'
        call ToLog(outext)        
        stop
    endif
   
    call init_caseconstants(xmldoc)
    call init_simdefs(xmldoc)
    call init_parameters(xmldoc)
    call init_sources(xmldoc)

    call destroy(xmldoc)

    return

    end subroutine


    end module initialize
