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

function [ iType ] = CEDS64ChanType( fhand, iChan )
%CEDS64CHANTYPE Returns an integer code corresponding to the channel type
%   [ iType ] = CEDS64ChanType( fhand, iChan )
%   Inputs
%   fhand - Integer file handle
%   iChan - Channel number
%   Outputs
%   iType - 0 no channel
%           1 Waveform channel
%           2 Event (falling)
%           3 Event (rising)
%           4 Event (both)
%           5 Marker
%           6 Wavemark
%           7 Realmark
%           8 TextMark
%           9 Realwave
%           or a negative error code
if(nargin == 2)
    iType = calllib('ceds64int', 'S64ChanType', fhand, iChan);
else
    iType = -22;
end
end

