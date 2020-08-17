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

function [ dTBaseOut ] = CEDS64TimeBase( fhand, dTBaseIn )
%CEDS64TIMEBASE Gets and sets the file time base
%   [ dTBaseOut ] = CEDS64TimeBase( fhand, dTBaseIn )
%   Inputs
%   fhand - An integer handle to an open file
%   dTBaseIn - (Optional) The new time base as a double
%   Outputs
%   dTBaseOut - The old time base as a double, or a number <= 0 if an error.

if (nargin == 1 || nargin == 2) % always get the old time bas
    dTBaseOut = calllib('ceds64int', 'S64GetTimeBase', fhand);
else
    dTBaseOut = -22;
end

% has there been an error?
if dTBaseOut < 0
    return;
end

% if not set the new time bas if we're given one
if (nargin == 2)
    calllib('ceds64int', 'S64SetTimeBase', fhand, dTBaseIn);
end

end

