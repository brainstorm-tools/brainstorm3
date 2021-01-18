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

function [ dRateOut ] = CEDS64IdealRate( fhand, iChan, dRateIn )
%CEDS64IDEALRATE Gets and sets ideal rate for a channel
%   [ dRateOut ] = CEDS64IdealRate( fhand, iChan {, dRateIn} )
%   Inputs
%   fhand - An integer handle to an open file
%   iChan - An integer channel number
%   dRateIn - (Optional) The new ideal rate
%   Outputs
%   dRateOut - The old ideal rate, otherwise a negative error code.

if (nargin == 2 || nargin == 3) % always get the old ideal rate
    dRateOut = calllib('ceds64int', 'S64GetIdealRate', fhand, iChan);
else
    dRateOut = -22;
end

% has there been an error?
if dRateOut < 0
    return;
end

% if not set the new ideal rate if we're given one
if (nargin == 3)
    dRateOut = calllib('ceds64int', 'S64GetIdealRate', fhand, iChan, dRateIn);
end
end

