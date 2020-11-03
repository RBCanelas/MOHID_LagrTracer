#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Created on Thu Oct  3 14:44:32 2019

@author: gfnl143
"""
import numpy as np
import xml.etree.ElementTree as ET
import src.constants as cte
from numba import jit


@jit(nopython=True)
def cellCountingJIT(rIdCell, nCells):
    cellCounts = np.empty(nCells)
    for idCell in range(0, nCells):
        cellCounts[idCell] = np.sum(idCell == rIdCell)
    return cellCounts


@jit(nopython=True)
def cellMeanDataJIT(rIdCell, nCells, validCells, varData):
    cellMean = np.zeros(nCells)
    for idCell in validCells:
        dataInCell = (idCell == rIdCell)*varData
        if dataInCell.size == 0:
            cellMean[idCell] = 0
        else:
            cellMean[idCell] = np.sum(dataInCell)/dataInCell.size
    return cellMean


class Grid:

    def __init__(self, xml_recipe, xml_file, dims=['depth', 'latitude', 'longitude']):
        self.xml_recipe = xml_recipe
        self.xml_file = xml_file
        self.grid = []
        self.cellCenters = []
        self.cellArea = []
        self.cellVolume = []
        self.dims = dims
        self.coords = {}
        self.countsInCell = []
        self.validCells = []
        self.meanDataInCell = []
        self.rIdCell = []

    def getGrid(self):
        root = ET.parse(self.xml_recipe).getroot()
        self.grid = len(self.dims)*[[]]
        for parameter in root.findall('EulerianMeasures/gridDefinition/'):
            if parameter.tag == 'BoundingBoxMin':
                x_min = np.float(parameter.get('x'))
                y_min = np.float(parameter.get('y'))
                z_min = np.float(parameter.get('z'))
            else:
                root_global = ET.parse(self.xml_file).getroot()
                bbox_min = root_global.find('caseDefinitions/simulation/BoundingBoxMin')
                x_min = np.float(bbox_min.get('x'))
                y_min = np.float(bbox_min.get('y'))
                z_min = np.float(bbox_min.get('z'))

            if parameter.tag == 'BoundingBoxMax':
                x_max = np.float(parameter.get('x'))
                y_max = np.float(parameter.get('y'))
                z_max = np.float(parameter.get('z'))
            else:
                root_global = ET.parse(self.xml_file).getroot()
                bbox_max = root_global.find('caseDefinitions/simulation/BoundingBoxMax')
                x_max = np.float(bbox_max.get('x'))
                y_max = np.float(bbox_max.get('y'))
                z_max = np.float(bbox_max.get('z'))

            if parameter.tag == 'resolution':
                x_step = np.float(parameter.get('x'))
                y_step = np.float(parameter.get('y'))
                z_step = np.float(parameter.get('z'))
            if parameter.tag == 'units':
                units_value = parameter.get('value')

        print('-> Grid counting domain:',
              ' lon:[', x_min, x_max, ']',
              ' lat:[', y_min, y_max, ']',
              ' depth:[', z_min, z_max, ']')

        if units_value == 'degrees':
            self.grid[2] = np.arange(x_min, x_max, x_step)
            self.grid[1] = np.arange(y_min, y_max, y_step)
            self.grid[0] = np.arange(z_min, z_max, z_step)
        elif units_value == 'relative':
            self.grid[2] = np.linspace(x_min, x_max, np.int(x_step + 1))
            self.grid[1] = np.linspace(y_min, y_max, np.int(y_step + 1))
            self.grid[0] = np.linspace(z_min, z_max, np.int(z_step + 1))
        elif units_value == 'meters':
            y_c = (y_max + y_min)/2.
            dlat = y_step/(cte.degreesToRad*cte.earthRadius)
            dlon = x_step/(cte.degreesToRad*cte.earthRadius * np.cos(cte.degreesToRad*(y_c)))
            self.grid[2] = np.arange(x_min, x_max, dlon)
            self.grid[1] = np.arange(y_min, y_max, dlat)
            self.grid[0] = np.arange(z_min, z_max, z_step)

        print('-> Grid cells',
              ' lon:[', self.grid[2].size, ']',
              ' lat:[', self.grid[1].size, ']',
              'depth:[', self.grid[0].size, ']'
              )
        return

    def getCellCenters(self):
        for value in self.grid:
            self.cellCenters.append((value[:-1] + value[1:])/2.)
        return

    def getCellAreas(self, units='km'):
        # check in order to reverse the axis dimensions
        # depths, lats, lons = np.meshgrid(self.grid['depth'],self.grid['latitude'],self.grid['longitude'],indexing='ij')
        # dx = (lons[1:]-lons[:-1])*(np.pi/180.)*6371837. * np.cos((np.pi/180.)*((lats[:-1] + lats[1:])/2.))
        dlon = (self.grid[2][1:] - self.grid[2][:-1])
        dlat = (self.grid[1][1:] - self.grid[1][:-1])
        y_c = (self.grid[1][1:] + self.grid[1][:-1])/2.
        # dx and dlon are in meters
        dx = dlon[np.newaxis, :] * (cte.degreesToRad * cte.earthRadius * np.cos(cte.degreesToRad*(y_c[:,np.newaxis])))
        dy = dlat*cte.degreesToRad*cte.earthRadius
        if units == 'km':
            dx = dx/1000.
            dy = dy/1000.
        self.cellArea = dx*dy[:, np.newaxis]

    def getCellVolumes(self, units='km'):
        dz = self.grid[0][1:]-self.grid[0][:-1]
        if units == 'km':
            dz = dz/1000.
        self.cellVolume = dz[:, np.newaxis, np.newaxis] * self.cellArea[np.newaxis, :, :]

    def getCoords(self):
        self.coords = {self.dims[0]: ([self.dims[0]], self.cellCenters[0]),
                       self.dims[1]: ([self.dims[1]], self.cellCenters[1]),
                       self.dims[2]: ([self.dims[2]], self.cellCenters[2])
                       }

    def initializeGrid(self):
        self.getGrid()
        self.getCellCenters()
        self.getCoords()
        self.getCellAreas()
        self.getCellVolumes()

    def PositionsToIdCell(self, particlePositions):
        nz = self.cellCenters[0].size
        ny = self.cellCenters[1].size
        nx = self.cellCenters[2].size
        if np.size(particlePositions.shape) == 1:
            particlePositions = particlePositions[np.newaxis, :]

        z_dig = np.digitize(particlePositions[:, 0], self.grid[0], right=True)
        y_dig = np.digitize(particlePositions[:, 1], self.grid[1], right=True)
        x_dig = np.digitize(particlePositions[:, 2], self.grid[2], right=True)

        self.rIdCell = np.ravel_multi_index((z_dig, y_dig, x_dig),
                                            (nz, ny, nx),
                                            mode='clip')

    def getCountsInCell(self, particlePositions):
        countsInCell, _ = np.histogramdd(particlePositions, self.grid)
        # self.validCells = self.countsInCell > 0
        # self.validCells = np.where(IdCounts > 0)[0]
        # self.countsInCell = np.reshape(IdCounts, (nz, ny, nx))
        return countsInCell

    def getMeanDataInCell(self, varData):
        nz = self.cellCenters[0].size
        ny = self.cellCenters[1].size
        nx = self.cellCenters[2].size
        nCells = nx*ny*nz
        cellMean = cellMeanDataJIT(self.rIdCell, nCells, self.validCells, varData)
        self.meanDataInCell = np.reshape(cellMean, (nz, ny, nx))

    def shape(self):
        return map(len, self.grid)
