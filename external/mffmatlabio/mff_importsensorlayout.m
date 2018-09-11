% mff_importsensorlayout - import information from MFF 'sensorLayout.xml' file
%
% Usage:
%   layout = mff_importsensorlayout(mffFile);
%
% Inputs:
%  mffFile - filename/foldername for the MFF file
%
% Output:
%  layout - Matlab structure containing informations contained in the MFF file.

% This file is part of mffmatlabio.
%
% mffmatlabio is free software: you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation, either version 3 of the License, or
% (at your option) any later version.
%
% mffmatlabio is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with mffmatlabio.  If not, see <https://www.gnu.org/licenses/>.

function [layout, rVal] = mff_importsensorlayout(mffFile)

layout = [];
rVal = true;

p = fileparts(which('mff_importsignal.m'));
warning('off', 'MATLAB:Java:DuplicateClass');
%javaaddpath(fullfile(p, 'MFF-1.2.2-jar-with-dependencies.jar'));
warning('on', 'MATLAB:Java:DuplicateClass');

% Create an MFFFactory object.
mfffactorydelegate = javaObject('com.egi.services.mff.api.LocalMFFFactoryDelegate');
mfffactory = javaObject('com.egi.services.mff.api.MFFFactory', mfffactorydelegate);

% Create Signal object and read in event track file.
sLayoutURI = fullfile(mffFile, 'sensorLayout.xml');
sensorLayoutType = javaObject('com.egi.services.mff.api.MFFResourceType', javaMethod('valueOf', 'com.egi.services.mff.api.MFFResourceType$MFFResourceTypes', 'kMFF_RT_SensorLayout'));

sLayout = mfffactory.openResourceAtURI(sLayoutURI, sensorLayoutType);


variables = ...
    { ...
    'Name'            'char'  {};
    'OriginalLayout'  'char'  {} ;
    'Sensors'         'array' { 'Name' 'char' {}; 'Number' 'real' {}; 'X' 'real' {}; 'Y' 'real' {}; 'Z' 'real' {}; 'Type' 'real' {}; 'Identifier' 'real' {} };
    'Threads'         'array' { 'First' 'real' {}; 'Second' 'real' {} };
    'TilingSets'      'array' { '' 'array' {} };
    'Neighbors'       'array' { 'ChannelNumber' 'real' {}; 'Neighbors' 'array' {} } };

layout = [];
if ~isempty(sLayout)
    try
        if sLayout.loadResource()
            layout = mff_getobj(sLayout, variables);
        end
    catch
        disp('Failed to load Layout ressource');
    end
end
