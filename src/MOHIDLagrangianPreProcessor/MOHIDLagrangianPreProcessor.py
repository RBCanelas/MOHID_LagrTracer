# -*- coding: utf-8 -*-

#    !------------------------------------------------------------------------------
#    !        IST/MARETEC, Water Modelling Group, Mohid modelling system
#    !------------------------------------------------------------------------------
#    !
#    ! TITLE         : MOHIDLagrangianPreProcessor
#    ! PROJECT       : MOHIDLagrangian
#    ! URL           : http://www.mohid.com
#    ! AFFILIATION   : IST/MARETEC, Marine Modelling Group
#    ! DATE          : April 2019
#    ! REVISION      : Canelas 0.1
#    !> @author
#    !> Ricardo Birjukovs Canelas
#    !
#    ! DESCRIPTION:
#    !Preprocessing script for MOHID Lagrangian. Lists input files, composes config 
#    !files, etc 
#    !------------------------------------------------------------------------------
#    
#    MIT License
#    
#    Copyright (c) 2018 RBCanelas
#    
#    Permission is hereby granted, free of charge, to any person obtaining a copy
#    of this software and associated documentation files (the "Software"), to deal
#    in the Software without restriction, including without limitation the rights
#    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#    copies of the Software, and to permit persons to whom the Software is
#    furnished to do so, subject to the following conditions:
#    
#    The above copyright notice and this permission notice shall be included in all
#    copies or substantial portions of the Software.
#    
#    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#    SOFTWARE.

import os
import sys
import argparse
import xml.etree.ElementTree as ET
from datetime import datetime, timedelta
import glob

basePath = os.path.dirname(os.path.realpath(__file__))
commonPath = os.path.abspath(os.path.join(basePath, "Common"))
sys.path.append(commonPath)
import os_dir
import about
import ncMetaParser
import xmlWriter


def run():
    
    lic = about.Licence()
    lic.print()
    
    #cmd line argument parsing---------------------------
    argParser = argparse.ArgumentParser(description='Indexes input files for MOHID Lagrangian to parse. Use -h for help.')
    argParser.add_argument("-i", "--input", dest="caseXML",
                    help=".xml file with the case definition for the MOHID Lagrangian run", metavar=".xml")
    argParser.add_argument("-o", "--outputDir", dest="outDir",
                    help="output directory", metavar=".xml")
    args = argParser.parse_args()
    
    caseXML = getattr(args,'caseXML')
    outDir = getattr(args,'outDir')
    print('-> Case definition file is ', caseXML)
    #---------------------------------------------------
    #parsing case definition file
    root = ET.parse(caseXML).getroot()
    
    dataDir = []
    dataType = []
    dataList = []
    for type_tag in root.findall('caseDefinitions/inputData/inputDataDir'):
        dataDir.append(type_tag.get('name'))
        dataType.append(type_tag.get('type'))
        dataList.append((type_tag.get('name'), type_tag.get('type')))
    
    for type_tag in root.findall('execution/parameters/parameter'):
        if type_tag.get('key') == 'Start':
            StartTime = datetime.strptime(type_tag.get('value'), "%Y %m %d %H %M %S")            
        if type_tag.get('key') == 'End':
            EndTime = datetime.strptime(type_tag.get('value'), "%Y %m %d %H %M %S")
            
    #------------------------------------------------------
    if len(dataList) > 1:
        print('-> Input data directories are', [row[0] for row in dataList])
    else:
        print('-> Input data directory is', dataList)

        
    #------------------------------------------------------
    fileExtensions = ['.nc', '.nc4']
    
    #going for each input directory and indexing its files
    inputFileCurrents = []
    inputFileWinds = []
    inputFileWaves = []
    for idir in dataList:
        for ext in fileExtensions:
            if idir[1] == 'currents':
                inputFileCurrents.append(glob.glob(idir[0]+ '/**/*'+ext, recursive=True))
            if idir[1] == 'waves':
                inputFileWaves.append(glob.glob(idir[0]+ '/**/*'+ext, recursive=True))
            if idir[1] == 'meteorology':
                inputFileWinds.append(glob.glob(idir[0]+ '/**/*'+ext, recursive=True))
    #cleaning list of empty values
    inputFileCurrents = list(filter(None, inputFileCurrents))
    inputFileWinds = list(filter(None, inputFileWinds))
    inputFileWaves = list(filter(None, inputFileWaves))

    #going for each input directory and indexing its files
    inputFiles = []
    for idir in dataDir:
        for ext in fileExtensions:
            inputFiles.append(glob.glob(idir+ '/**/*'+ext, recursive=True))
    #cleaning list of empty values
    inputFiles = list(filter(None, inputFiles))
    
    nInputs = len(inputFileCurrents) + len(inputFileWinds) + len(inputFileWaves)
    if nInputs == 0:
        print('No input files found. Supported files are ', fileExtensions)
    else:
    
        indexerFileName = os_dir.filename_without_ext(caseXML)+'_inputs'
        indexer = xmlWriter.xmlWriter(indexerFileName)
        inputFile = [inputFileCurrents, inputFileWinds, inputFileWaves]
        inputType = ['currents', 'waves', 'meteorology']
		
		#going trough every file, extracting some metadata and writting in the indexer file, for each file type
        i=0
        for inputList in inputFile:
            if len(inputList) > 0:
                ncMeta = []
                for idir in inputList:
                    for ifile in idir:
                        print('--> reading file', ifile)
                        ncMeta.append(ncMetaParser.ncMetadata(ifile, StartTime))
                ncMeta.sort(key=lambda x: x.startTime)
                indexer.openCollection(inputType[i])
                print('--> indexing',inputType[i],'data')
                for ncfile in ncMeta:
                    indexer.writeFile(ncfile.getName(), ncfile.getstartTime(), ncfile.getendTime(), ncfile.getstartDate().strftime("%Y %m %d %H %M %S"), ncfile.getendDate().strftime("%Y %m %d %H %M %S"))		
                indexer.closeCollection(inputType[i])
                i = i+1
        
        indexer.closeFile()
        print('-> All done, wrote', indexerFileName+'.xml', 'indexing file')
            
run()