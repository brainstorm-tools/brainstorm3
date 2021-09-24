function build_readPLXFileC(debug)
% BUILD_READPLXFILEC - Wrapper for building the readPLXFileC MEX function.
% 
% This function can be used to compile readPLXFileC. It embeds into the
% resulting MEX file the date/time the source code was last modified, which
% is useful for comparing and debugging different revisions of the code.
%
% The only input (debug) is true/false and dicates whether the debugging
% flags are enabled in the resulting MEX file ('true' adds the '-g' flag
% when calling 'mex'). Default is false.
%
% Author: Benjamin Kraus (bkraus@bu.edu, ben@benkraus.com)
% Last Modified: $Date: 2013-06-09 19:58:09 -0400 (Sun, 09 Jun 2013) $
% Copyright (c) 2012-2013, Benjamin Kraus
% $Id: build_readPLXFileC.m 4905 2013-06-09 23:58:09Z bkraus $

% By default build a 'release' package, instead of a 'debugging' package.
if(nargin < 1); debug = false; end

% File name of the source code.
f = 'readPLXFileC';

% Get the date the file was last modified.
finfo = dir([f '.c']);

% If the source code isn't in the current directory, try and find it.
if(isempty(finfo))
    p = which(f);
    
    % If we can't find it, throw an error.
    assert(~isempty(p),[mfilename ':BinaryNotFound'],...
        ['Unable to find a compiled binary for ''%s'' on the path, ',...
         'change directories to the location of ''%s.c'''],f,f);
    
    % Find the full path to the file.
    p = fileparts(p);
    f = [p filesep f '.c'];
    
    % Get the date the file was last modified.
    finfo = dir(f);
else p = '.'; f = [f '.c'];
end

% If we can't find the source code, throw an error.
assert(~isempty(finfo),[mfilename ':SourceNotFound'],...
    ['Unable to find source file for ''%s'', ',...
     'change directories to the location of ''%s.c'''],f,f);

% Prepare the symbols to pass to the compiler, including the data and time.
d = sprintf('-DLASTMODDATE=%s',datestr(finfo.date,'yyyy-mm-dd'));
t = sprintf('-DLASTMODTIME=%s',datestr(finfo.date,'HH:MM:SS'));

% Compile the function
if(debug)
    % Compile with debugging symbols.
    mex('-g',d,t,'-outdir',p,f);
else
    % Compile for release (without debugging symbols).
    mex(d,t,'-outdir',p,f);
end    

end
