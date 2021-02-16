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

function [ iOk, TimeDateOut ] = CEDS64TimeDate( fhand, TimeDateIn )
%CEDS64TIMEDATE Gets and sets the time and date saved in a file (usually the time that sampling began)
% Note this is not the same format as MATLAB's clock function
%   [ iOk, TimeDateOut ] = CEDS64TimeDate( fhand, TimeDateIn )
%   Inputs
%   fhand - Integer file handle
%   TimeDateIn - (Optional) The new time date as a 7-by-1 vector
%   Outputs
%   iOk = 0 if the operation completed without error, otherwise a negative
%   error code. 
%   TimeDateOut - The old time date as a 7-by-1 vector
%   The structure of the time-date vector is:
%   element 1 - hundredths of seconds (0-99)
%   element 2 - seconds (0-59)
%   element 3 - minutes (0-59)
%   element 4 - hours (0-23)
%   element 5 - day of the month (1-31)
%   element 6 - month of the year (1-12)
%   element 7 - year (1980-2200)

%TimeDateOut = zeros(7, 1, 'int32');

if (nargin == 1 || nargin == 2) % get the old TimeDate
    dBufferIn = int64(0);
    dBufferOut = int64(0);
    [ iOk, A ] = calllib('ceds64int', 'S64TimeDate', fhand, dBufferOut, dBufferIn, -1);
    TimeDateOut(1) = bitand(bitshift(A, 0), 255);     % Hundredth of a second  
    TimeDateOut(2) = bitand(bitshift(A, -8), 255);    % Second  
    TimeDateOut(3) = bitand(bitshift(A, -16), 255);   % Minute
    TimeDateOut(4) = bitand(bitshift(A, -24), 255);   % Hour
    TimeDateOut(5) = bitand(bitshift(A, -32), 255);   % day
    TimeDateOut(6) = bitand(bitshift(A, -40), 255);   % month
    TimeDateOut(7) = bitand(bitshift(A, -48), 65535); % year
else
   iOk = -22;
   return;
end

% set the new TimeDate if we're given one
if (nargin == 2)
    if (length(TimeDateIn) ~= 7)
        iOk = -22;
        return;
    end
	dBufferIn = int64(0);
    dBufferOut = int64(0);
    dBufferIn = dBufferIn + TimeDateIn(1);
    dBufferIn = dBufferIn + bitshift(TimeDateIn(2), 8);
    dBufferIn = dBufferIn + bitshift(TimeDateIn(3), 16);  
    dBufferIn = dBufferIn + bitshift(TimeDateIn(4), 24);
    dBufferIn = dBufferIn + bitshift(TimeDateIn(5), 32);
    dBufferIn = dBufferIn + bitshift(TimeDateIn(6), 40);    
    dBufferIn = dBufferIn + bitshift(TimeDateIn(7), 48);
    [ iOk, A ] = calllib('ceds64int', 'S64TimeDate', fhand, dBufferOut, dBufferIn, 0);
end
end

