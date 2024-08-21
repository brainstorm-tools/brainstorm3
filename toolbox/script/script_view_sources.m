function [hFig, iDS, iFig] = script_view_sources(ResultsFile, DisplayMode)
% SCRIPT_VIEW_SOURCES: Display the sources or timefreq from sources in a brainstorm figure.
%
% USAGE:  [hFig, iDS, iFig] = script_view_sources(ResultsFile, DisplayMode)
%
% INPUT:
%     - ResultsFile : relative of full path to file to display
%     - DisplayMode : {'cortex', 'mri3d', 'mriviewer'}

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
% Author: Francois Tadel, 2009-2010
%         Raymundo Cassani, 2024

% Find Study for input file in database
[sStudy, ~, ~, fileType, sItem] = bst_get('AnyFile', ResultsFile);
% Check file type
if ~ismember(fileType, {'results', 'timefreq'})
    error('Input file must contain sources, or be a timefreq file from sources.');
end
% TimeFreq must be from sources
if strcmpi(fileType, 'timefreq')
    if ~strcmpi(sItem.DataType, 'results')
        error('Input file must be a timefreq file from sources.');
    end
end
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




