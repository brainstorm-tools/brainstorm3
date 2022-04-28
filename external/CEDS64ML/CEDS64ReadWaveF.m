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

function [ iRead, fVals, i64Time ] = CEDS64ReadWaveF( fhand, iChan, iN, i64From, i64To, maskh )
%CEDS64READWAVE32 Reads wave data from a waveform or realwave channel as singles (32-bit floats).
%   [ iRead, fVals, i64Time ] = CEDS64ReadWaveF( fhand, iChan, iN, i64From {, i64To {, maskh} } )
%   Inputs
%   fhand - An integer handle to an open file
%   iChan - A channel number for a Waveform or Realwave channel
%   iN - The maximum number of data points  to copy
%   i64From - The time in ticks of the earliest time you want to read
%   i64To - (Optional) The time in ticks of the latest time you want to
%   read. If not set or set to -1, read to the end of the channel
%   maskh - (Optional) An integer handle to a marker mask (only used when reading wavemarkers)
%   Outputs
%   iRead - The number of data points read
%   fVals - An array of floats conatining the data points
%   i64Time - The time in ticks of the first data point

if (nargin < 4)
    iRead = -22;
    return;
end

outwavepointer = zeros(iN,1, 'single');
outtimepointer = zeros(1,1,'int64');

if (nargin < 5)
    i64To = -1;
end

if (nargin < 6)
    maskcode = -1;
else
    maskcode = maskh;
end

[iRead, fVals, i64Time] = calllib('ceds64int', 'S64ReadWaveF', fhand, iChan, outwavepointer, iN, i64From, i64To, outtimepointer, maskcode);

if iRead > 0 
    fVals(iRead+1:end) = [];
else
    fVals = [];
end
end

