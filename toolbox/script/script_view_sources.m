function [hFig, iDS, iFig] = script_view_sources(ResultsFile, DisplayMode)
% SCRIPT_VIEW_SOURCES: Display the sources in a brainstorm figure.
%
% USAGE:  [hFig, iDS, iFig] = script_view_sources(ResultsFile, DisplayMode)
%
% INPUT:
%     - ResultsFile : relative of full path to file to display
%     - DisplayMode : {'cortex', 'mri3d', 'mriviewer'}

% @=============================================================================
% This function is part of the Brainstorm software:
% http://neuroimage.usc.edu/brainstorm
% 
% Copyright (c)2000-2018 University of Southern California & McGill University
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
% Author: Francois Tadel, 2009-2010

% Find results file in database
[sStudy, iStudy, iResult] = bst_get('ResultsFile', ResultsFile);
% Find subject in database
sSubject = bst_get('Subject', sStudy.BrainStormSubject);

% Switch between display modes
switch lower(DisplayMode)
    case 'cortex'
        % Get default cortex file
        CortexFile = sSubject.Surface(sSubject.iCortex).FileName;
        % Call surface viewer
        [hFig, iDS, iFig] = view_surface_data(CortexFile, ResultsFile, [], 'NewFigure');
    case 'mri3d'
        % Get default cortex file
        MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
        % Call surface viewer
        [hFig, iDS, iFig] = view_surface_data(MriFile, ResultsFile, [], 'NewFigure');
    case 'mriviewer'
        % Get default cortex file
        MriFile = sSubject.Anatomy(sSubject.iAnatomy).FileName;
        % Call surface viewer
        [hFig, iDS, iFig] = view_mri(MriFile, ResultsFile);
end




