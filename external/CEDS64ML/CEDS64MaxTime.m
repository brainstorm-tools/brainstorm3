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

function [ i64MaxTime ] = CEDS64MaxTime( fhand )
%CEDS64MAXTIME Returns the maximum time in ticks of all channels for a SON file
%   [ i64MaxTime ] = CEDS64MaxTime( fhand )
%   Inputs
%   fhand - Integer file handle
%   Outputs
%   i64MaxTime - the maximum time in ticks of all channels in this file, 
%   otherwise a negative error code.

if (nargin ~= 1)
    i64MaxTime = -22;
    return;
end

i64MaxTime = calllib('ceds64int', 'S64MaxTime', fhand);
end