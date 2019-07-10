    !------------------------------------------------------------------------------
    !        IST/MARETEC, Water Modelling Group, Mohid modelling system
    !------------------------------------------------------------------------------
    !
    ! TITLE         : Mohid Model
    ! PROJECT       : Mohid Lagrangian Tracer
    ! MODULE        : simulation_input_streamer
    ! URL           : http://www.mohid.com
    ! AFFILIATION   : IST/MARETEC, Marine Modelling Group
    ! DATE          : November 2018
    ! REVISION      : Canelas 0.1
    !> @author
    !> Ricardo Birjukovs Canelas
    !
    ! DESCRIPTION:
    !> Defines an input file reader class with an object exposable to the Simulation
    !> This class is in charge of selectig the correct reader for the selected input
    !> file format and controling the respective reader.
    !------------------------------------------------------------------------------

    module simulationInputStreamer_mod

    use common_modules
    use xmlParser_mod
    use netcdfParser_mod
    use fieldTypes_mod
    use background_mod
    use blocks_mod
    use boundingbox_mod

    use FoX_dom

    implicit none
    private

    type :: inputFileModel_class !< Input file model class
        type(string) :: name        !< name of the file
        real(prec) :: startTime     !< starting time of the data on the file
        real(prec) :: endTime       !< ending time of the data on the file
        logical :: used             !< flag that indicates the file is no longer to be read
        logical :: toRead
    end type inputFileModel_class

    type :: input_streamer_class        !< Input Streamer class
        logical :: useInputFiles
        type(inputFileModel_class), allocatable, dimension(:) :: currentsInputFile !< array of input file metadata for currents
        type(inputFileModel_class), allocatable, dimension(:) :: windsInputFile !< array of input file metadata for currents
        type(inputFileModel_class), allocatable, dimension(:) :: wavesInputFile !< array of input file metadata for currents
        integer :: nFileTypes
        real(prec) :: bufferSize                                               !< half of the biggest tail of data behind current time
        real(prec) :: lastReadTime
        integer :: currentsBkgIndex, windsBkgIndex, wavesBkgIndex
    contains
    procedure :: initialize => initInputStreamer
    procedure :: loadDataFromStack
    procedure, private :: getCurrentsFile
    procedure, private :: resetReadStatus
    procedure :: print => printInputStreamer
    end type input_streamer_class

    !Public access vars
    public :: input_streamer_class

    contains
    
    !---------------------------------------------------------------------------
    !> @author Ricardo Birjukovs Canelas - MARETEC
    !> @brief
    !> instantiates and returns a background object with the data from a 
    !> currents input file
    !> @param[in] self, fileName
    !---------------------------------------------------------------------------
    type(background_class) function getCurrentsFile(self, fileName)
    class(input_streamer_class), intent(in) :: self
    type(string), intent(in) :: fileName
    type(string), allocatable, dimension(:) :: varList
    logical, allocatable, dimension(:) :: syntecticVar
    type(ncReader_class) :: ncReader
    
    allocate(varList(5))
    allocate(syntecticVar(5))
    varList(1) = Globals%Var%u
    syntecticVar(1) = .false.
    varList(2) = Globals%Var%v
    syntecticVar(2) = .false.
    varList(3) = Globals%Var%w
    syntecticVar(3) = .false.
    varList(4) = Globals%Var%landMask
    syntecticVar(4) = .true.
    varList(5) = Globals%Var%landIntMask
    syntecticVar(5) = .true.
    
    !need to send to different readers here if different file formats    
    getCurrentsFile = ncReader%getFullFile(fileName, varList, syntecticVar)
    call getCurrentsFile%makeLandMask()
    
    end function

    !---------------------------------------------------------------------------
    !> @author Ricardo Birjukovs Canelas - MARETEC
    !> @brief
    !> loads data from files and populates the backgrounds accordingly
    !> @param[in] self, bbox, blocks
    !---------------------------------------------------------------------------
    subroutine loadDataFromStack(self, bBox, blocks)
    class(input_streamer_class), intent(inout) :: self
    type(boundingbox_class), intent(in) :: bBox            !< Case bounding box
    type(block_class), dimension(:), intent(inout) :: blocks  !< Case Blocks
    type(background_class) :: tempBkgd
    integer :: i, j
    integer :: fNumber
    real(prec) :: tempTime(2)
    logical :: needToRead, appended

    needToRead = .false.
    if (self%useInputFiles) then
        !check if we need to import data (current time and buffer size)
        if (self%lastReadTime <= Globals%SimTime%CurrTime + self%BufferSize/4.0) needToRead = .true.
        if (self%lastReadTime >= Globals%SimTime%TimeMax) needToRead = .false.
        if (needToRead) then
            call self%resetReadStatus()
            !check what files on the stack are to read to backgrounds
            if (allocated(self%currentsInputFile)) then
                do i=1, size(self%currentsInputFile)
                    if (self%currentsInputFile(i)%endTime >= Globals%SimTime%CurrTime) then
                        if (self%currentsInputFile(i)%startTime <= Globals%SimTime%CurrTime + self%BufferSize) then
                            if (.not.self%currentsInputFile(i)%used) self%currentsInputFile(i)%toRead = .true.
                        end if
                    end if
                end do
            end if
            if (allocated(self%windsInputFile)) then
                do i=1, size(self%windsInputFile)
                    if (self%windsInputFile(i)%endTime >= Globals%SimTime%CurrTime) then
                        if (self%windsInputFile(i)%startTime <= Globals%SimTime%CurrTime + self%BufferSize) then
                            if (.not.self%windsInputFile(i)%used) self%windsInputFile(i)%toRead = .true.
                        end if
                    end if
                end do
            end if
            if (allocated(self%wavesInputFile)) then
                do i=1, size(self%wavesInputFile)
                    if (self%wavesInputFile(i)%endTime >= Globals%SimTime%CurrTime) then
                        if (self%wavesInputFile(i)%startTime <= Globals%SimTime%CurrTime + self%BufferSize) then
                            if (.not.self%wavesInputFile(i)%used) self%wavesInputFile(i)%toRead = .true.
                        end if
                    end if
                end do
            end if
            !read selected files
            do i=1, size(self%currentsInputFile)
                if (self%currentsInputFile(i)%toRead) then
                    !import data to temporary background
                    tempBkgd = self%getCurrentsFile(self%currentsInputFile(i)%name)
                    self%currentsInputFile(i)%used = .true.
                    do j=1, size(blocks)
                        !slice data by block and either join to existing background or add a new one
                        if (blocks(j)%Background(self%currentsBkgIndex)%initialized) call blocks(j)%Background(self%currentsBkgIndex)%append(tempBkgd%getHyperSlab(blocks(j)%extents), appended)
                        if (.not.blocks(j)%Background(self%currentsBkgIndex)%initialized) blocks(j)%Background(self%currentsBkgIndex) = tempBkgd%getHyperSlab(blocks(j)%extents)
                        !save last time already loaded
                        tempTime = blocks(j)%Background(self%currentsBkgIndex)%getDimExtents(Globals%Var%time)
                        self%lastReadTime = tempTime(2)
                    end do
                    !clean out the temporary background data (this structure, even tough it is a local variable, has pointers inside)
                    call tempBkgd%finalize()
                end if
            end do
        end if
    end if

    end subroutine loadDataFromStack

    !---------------------------------------------------------------------------
    !> @author Ricardo Birjukovs Canelas - MARETEC
    !> @brief
    !> Initializes the input writer object, imports metadata on input files
    !---------------------------------------------------------------------------
    subroutine initInputStreamer(self, blocks)
    class(input_streamer_class), intent(inout) :: self
    type(block_class), dimension(:), intent(inout) :: blocks  !< Case Blocks
    type(Node), pointer :: xmlInputs           !< .xml file handle
    type(Node), pointer :: typeNode
    type(Node), pointer :: fileNode
    type(NodeList), pointer :: fileList
    type(string) :: tag, att_name, att_val
    type(string), allocatable, dimension(:) :: fileNames
    integer :: i, nBkg

    self%bufferSize = Globals%Parameters%BufferSize
    self%lastReadTime = -1.0
    self%nFileTypes = 0
    self%currentsBkgIndex = 0
    self%windsBkgIndex = 0
    self%wavesBkgIndex = 0
    nBkg = 0

    call XMLReader%getFile(xmlInputs,Globals%Names%inputsXmlFilename, mandatory = .false.)
    if (associated(xmlInputs)) then
        self%useInputFiles = .true.
        !Go to the file_collection node
        tag = "file_collection"
        call XMLReader%gotoNode(xmlInputs,xmlInputs,tag)

        !For currents data
        tag = Globals%DataTypes%currents
        call XMLReader%gotoNode(xmlInputs,typeNode,tag, mandatory=.false.)
        if (associated(typeNode)) then
            fileList => getElementsByTagname(typeNode, "file")
            allocate(fileNames(getLength(fileList)))
            allocate(self%currentsInputFile(getLength(fileList)))
            do i = 0, getLength(fileList) - 1
                fileNode => item(fileList, i)
                tag="name"
                att_name="value"
                call XMLReader%getNodeAttribute(fileNode, tag, att_name, fileNames(i+1))
                self%currentsInputFile(i+1)%name = fileNames(i+1)
                tag="startTime"
                att_name="value"
                call XMLReader%getNodeAttribute(fileNode, tag, att_name, att_val)
                self%currentsInputFile(i+1)%startTime = att_val%to_number(kind=1._R4P)
                tag="endTime"
                att_name="value"
                call XMLReader%getNodeAttribute(fileNode, tag, att_name, att_val)
                self%currentsInputFile(i+1)%endTime = att_val%to_number(kind=1._R4P)
                self%currentsInputFile(i+1)%used = .false.
            end do
            deallocate(fileNames)
            nBkg = nBkg + 1
            self%currentsBkgIndex = nBkg
        end if

        !For wind data
        tag = Globals%DataTypes%winds
        call XMLReader%gotoNode(xmlInputs,typeNode,tag, mandatory=.false.)
        if (associated(typeNode)) then
            fileList => getElementsByTagname(typeNode, "file")
            allocate(fileNames(getLength(fileList)))
            allocate(self%windsInputFile(getLength(fileList)))
            do i = 0, getLength(fileList) - 1
                fileNode => item(fileList, i)
                tag="name"
                att_name="value"
                call XMLReader%getNodeAttribute(fileNode, tag, att_name, fileNames(i+1))
                self%windsInputFile(i+1)%name = fileNames(i+1)
                tag="startTime"
                att_name="value"
                call XMLReader%getNodeAttribute(fileNode, tag, att_name, att_val)
                self%windsInputFile(i+1)%startTime = att_val%to_number(kind=1._R4P)
                tag="endTime"
                att_name="value"
                call XMLReader%getNodeAttribute(fileNode, tag, att_name, att_val)
                self%windsInputFile(i+1)%endTime = att_val%to_number(kind=1._R4P)
                self%windsInputFile(i+1)%used = .false.
            end do
            deallocate(fileNames)
            nBkg = nBkg + 1
            self%windsBkgIndex = nBkg
        end if

        !For wave data
        tag = Globals%DataTypes%waves
        call XMLReader%gotoNode(xmlInputs,typeNode,tag, mandatory=.false.)
        if (associated(typeNode)) then
            fileList => getElementsByTagname(typeNode, "file")
            allocate(fileNames(getLength(fileList)))
            allocate(self%wavesInputFile(getLength(fileList)))
            do i = 0, getLength(fileList) - 1
                fileNode => item(fileList, i)
                tag="name"
                att_name="value"
                call XMLReader%getNodeAttribute(fileNode, tag, att_name, fileNames(i+1))
                self%wavesInputFile(i+1)%name = fileNames(i+1)
                tag="startTime"
                att_name="value"
                call XMLReader%getNodeAttribute(fileNode, tag, att_name, att_val)
                self%wavesInputFile(i+1)%startTime = att_val%to_number(kind=1._R4P)
                tag="endTime"
                att_name="value"
                call XMLReader%getNodeAttribute(fileNode, tag, att_name, att_val)
                self%wavesInputFile(i+1)%endTime = att_val%to_number(kind=1._R4P)
                self%wavesInputFile(i+1)%used = .false.
            end do
            nBkg = nBkg + 1
            self%wavesBkgIndex = nBkg
        end if
        !call Globals%setInputFileNames(fileNames)
    else
        self%useInputFiles = .false.
    end if
    !allocating the necessary background array in every block
    do i=1, size(blocks)
        allocate(blocks(i)%Background(nBkg))
    end do
    end subroutine initInputStreamer

    !---------------------------------------------------------------------------
    !> @author Ricardo Birjukovs Canelas - MARETEC
    !> @brief
    !> resets input files read status
    !---------------------------------------------------------------------------
    subroutine resetReadStatus(self)
    class(input_streamer_class), intent(inout) :: self
    integer :: i
    do i=1, size(self%currentsInputFile)
        self%currentsInputFile(i)%toRead = .false.
    end do
    end subroutine resetReadStatus

    !---------------------------------------------------------------------------
    !> @author Ricardo Birjukovs Canelas - MARETEC
    !> @brief
    !> Prints the input writer object and metadata on input files
    !---------------------------------------------------------------------------
    subroutine printInputStreamer(self)
    class(input_streamer_class), intent(in) :: self
    type(string) :: outext, temp_str
    integer :: i
    logical :: written
    written = .false.
    outext = '-->Input streamer stack:'//new_line('a')
    if (size(self%currentsInputFile) /= 0) then
        outext = outext//'--->'//Globals%DataTypes%currents%startcase()//' data '
        do i=1, size(self%currentsInputFile)
            outext = outext//new_line('a')
            outext = outext//'---->File '//self%currentsInputFile(i)%name
        end do
        written = .true.
    end if
    if (size(self%windsInputFile) /= 0) then
        if (written) outext = outext//new_line('a')
        outext = outext//'--->'//Globals%DataTypes%winds%startcase()//' data '
        do i=1, size(self%windsInputFile)
            outext = outext//new_line('a')
            outext = outext//'---->File '//self%windsInputFile(i)%name
        end do
        written = .true.
    end if
    if (size(self%wavesInputFile) /= 0) then
        if (written) outext = outext//new_line('a')
        outext = outext//'--->'//Globals%DataTypes%waves%startcase()//' data '
        do i=1, size(self%wavesInputFile)
            outext = outext//new_line('a')
            outext = outext//'---->File '//self%wavesInputFile(i)%name
        end do
    end if
    if (.not.self%useInputFiles) outext = '-->Input streamer stack is empty, no input data'
    call Log%put(outext,.false.)
    end subroutine printInputStreamer

    end module simulationInputStreamer_mod