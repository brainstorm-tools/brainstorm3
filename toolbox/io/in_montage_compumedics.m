function sMontage = in_montage_compumedics(filename)
% IN_MONTAGE_COMPUMEDICS:  Read a montagne file saved by Compumedics ProFusion.

% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
% 
% Copyright (c) University of Southern California & McGill University
% This software is distributed under the terms of the GNU General Public License
% as published by the Free Software Foundation. Further details on the GPLv3
% license can be found at http://www.gnu.org/copyleft/gpl.html.
% 
% FOR RESEARCH PURPOSES ONLY. THE SOFTWARE IS PROVIDED "AS IS," AND THE
% UNIVERSITY OF SOUTHERN CALIFORNIA AND ITS COLLABORATORS DO NOT MAKE ANY
% WARRANTY, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO WARRANTIES OF
% MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, NOR DO THEY ASSUME ANY
% LIABILITY OR RESPONSIBILITY FOR THE USE OF THIS SOFTWARE.
%
% For more information type "brainstorm license" at command prompt.
% =============================================================================@
%
% Authors: Francois Tadel, 2015

% Split filename
[fPath, fBase, fExt] = bst_fileparts(filename);
% Initialize returned structure
sMontage = db_template('Montage');
% Name of the montage = filename
sMontage.Name = fBase;

% Read XML file
sXml = in_xml(filename);
% Get first montage
sTraces = sXml.Montage.TracePanes(1).TracePane.Traces.Trace;

% Create simple selection of sensors
sMontage.Type      = 'selection';
sMontage.ChanNames = {'channel_name1', 'channel_name2'};
sMontage.DispNames = {'display_name1', 'display_name2'};
sMontage.Matrix    = eye(length(sMontage.ChanNames));

% Custom re-referecing or averaging matrix 
sMontage.Type      = 'text';     % If you want it to be edited as text in the montage editor
sMontage.Type      = 'matrix';   % If you want it to be visible as a matrix in the montage editor
sMontage.ChanNames = {'channel_name1', 'channel_name2'};
sMontage.DispNames = {'display_name1', 'display_name2'};
sMontage.Matrix    = zeros(length(sMontage.DispNames), length(sMontage.ChanNames));     % This matrix can be used to do any linear combination of the 




