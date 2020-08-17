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

function [ iOk ] = CEDS64LoadLib( sPath )
%CEDS64LOADLIB Loads ceds64int.dll allowing MATLAB to interface directly with
% CED's SON files. This function should be called first.
% sPath is a string containing a path the CEDMATLAB folder
% Remember to call unloadlibrary ceds64int when you have finished!


if (nargin ~= 1) % we must have a path
    iOk = -22;
    return;
end

% supress warning about casting objects as structs
warning('off','MATLAB:structOnObject');

% work out what system we are working on (32 or 64-bit)
machine = computer('arch');
if (strcmp(machine,'win32'))
    Type = 32;
else
    Type = 64;
end

% is the library loaded?
if ~libisloaded('ceds64int') % if not...
    if (Type == 32) %...find the 32-bit .dll and...
        libpath = strcat(sPath, '\x86');
        addpath(libpath);
        loadlibrary ('ceds64int.dll', @ceds32Prot); %...load it
    else
        libpath = strcat(sPath, '\x64');
        addpath(libpath);
        loadlibrary ('ceds64int', @ceds64Prot); %...load it
    end
else % if so...
    CEDS64CloseAll(); % ...close all open SON files...
    unloadlibrary ceds64int;   % ...unload the library...
    
    if (Type == 32) %...find the 32-bit .dll and...
        libpath = strcat(sPath, '\x86');
        addpath(libpath);
        loadlibrary ('ceds64int.dll', @ceds32Prot); %...load it
    else
        libpath = strcat(sPath, '\x64');
        addpath(libpath);
        loadlibrary ('ceds64int', @ceds64Prot); %...load it
    end
end
end

