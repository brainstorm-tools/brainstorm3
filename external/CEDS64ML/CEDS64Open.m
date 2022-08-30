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

function [ fhand ] = CEDS64Open( sFileName, iMode )
%CEDS64OPEN Opens an exiting SON file
%   [ fhand ] = CEDS64Open( sFileName {, iMode} )
%   Inputs
%   sFileName - String contain the path and file of the file we wish to
%   iMode - (Optional) 1= read only, 0 = read and write, -1 try to open as
%   read write, if that fails try to open a read only open
%   Outputs
%   fhand - An integer handle for the file, otherwise a negative error code.

if (nargin < 1)
    fhand = -22;
    return;
end

if (nargin == 1)
    iMode = 1;
end

fhand = calllib('ceds64int', 'S64Open', sFileName, iMode);
end

