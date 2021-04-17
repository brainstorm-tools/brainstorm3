%{
    Copyright (C) Cambridge Electronic Design Limited 2014
    Author: James Thompson
    Web: www.ced.co.uk email: james@ced.co.uk, softhelp@ced.co.uk

    This file is part of CEDS64ML, a MATLAB interface to the SON64 library.

    CEDS64ML is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    CEDS64ML is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with CEDS64ML.  If not, see <http://www.gnu.org/licenses/>.
%}

function [ iRead, cMarkers ] = CEDS64ReadMarkers( fhand, iChan, iN, i64From, i64To, maskh )
%CEDS64READMARKERS Reads marker data from a marker or extended marker channels
%   [ iRead, cMarkers ] = CEDS64ReadMarkers( fhand, iChan, iN, i64From {, i64To {, maskh}} )
%   Inputs
%   fhand - An integer handle to an open file
%   iChan - A channel number for an event or extended event channel
%   iN - The maximum number of data points to read
%   i64From - The time in ticks of the earliest time you want to read
%   i64To - (Optional) The time in ticks of the latest time you want to
%   read. If not set or set to -1, read to the end of the channel
%   maskh - (Optional) An integer handle to a marker mask
%   Outputs
%   iRead - The number of data points read
%   cMarkers - An array of CED64Markers

if (nargin < 4)
    iRead = -22;
    return;
end

markerBuffer = repmat(struct(CEDMarker()), iN, 1);
outmarkerpointer = libpointer('S64Marker', markerBuffer);

if (nargin < 5)
    i64To = -1;
end

if (nargin < 6)
    maskcode = -1;
else
    maskcode = maskh;
end

[ iRead ] = calllib('ceds64int', 'S64ReadMarkers', fhand, iChan, outmarkerpointer , iN, i64From, i64To, maskcode);

if (iRead <= 0)
    cMarkers = [];
    return;
end

cMarkers(iRead, 1) = CEDMarker();

for m=0:(iRead-1)
    temp = (outmarkerpointer + m);
    cMarkerTemp = temp.value;
	cMarkers(m+1).SetTime( cMarkerTemp.m_Time );
    cMarkers(m+1).SetCode( 1, cMarkerTemp.m_Code1 );
    cMarkers(m+1).SetCode( 2, cMarkerTemp.m_Code2 );
    cMarkers(m+1).SetCode( 3, cMarkerTemp.m_Code3 );
    cMarkers(m+1).SetCode( 4, cMarkerTemp.m_Code4 );
end
end

