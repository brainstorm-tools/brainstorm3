function [hFig, iDS, iFig] = view_covariance(CovarianceFile, Modality, hFig)
% view_covariance: Display a NxN covariance matrix
%
% USAGE:[hFig, iDS, iFig] = view_covariance(CovarianceFile, Modality=[])
%
% INPUT: 
%     - CovarianceFile : Path to covariance file to visualize
%     - Modality  : selected modality. empty to display all available sensors
%
% OUTPUT : 
%     - hFig : Matlab handle to the figure that was created or updated
%     - iDS  : DataSet index in the GlobalData variable
%     - iFig : Indice of returned figure in the GlobalData(iDS).Figure array

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
% Authors: Edouard Delaire, 2026

    %% ===== PARSE INPUTS =====
    if (nargin < 2) || isempty(Modality)
        Modality =  {'MEG', 'MEG MAG', 'MEG GRAD', 'EEG', 'NIRS', 'SEEG', 'ECOG'};
    end
    if (nargin < 3) || isempty(hFig) || isequal(hFig,0)
        hFig = [];
    elseif isequal(hFig,'NewFigure')
        hFig = [];
    end

    % Initializations
    iDS     = [];
    
    %% ===== LOAD COVARIANCE FILE =====
    % Find file in database
    [sStudy, iStudy, iNoiseCov] = bst_get('NoiseCovFile', CovarianceFile);
    if isempty(sStudy)
        error('File is not registered in database.');
    end
    sCov = in_bst_matrix( sStudy.NoiseCov(iNoiseCov).FileName);
    
    % Load channel information
    ChannelMat = in_bst_channel(sStudy.Channel.FileName);
    if ~isempty(Modality)
        iMod = good_channel(ChannelMat.Channel, [], Modality);
        ChannelMat.Channel = ChannelMat.Channel(iMod);
        sCov.NoiseCov = sCov.NoiseCov(iMod, iMod);        
    end
    
    % Get channel names
    RefRowNames = {ChannelMat.Channel.Name};
    RowNames    = {ChannelMat.Channel.Name};
    
    %% ===== DISPLAY AS IMAGE =====
    [hFig, iDSs, iFig] = view_image_reg(sCov.NoiseCov, ...
                                        {RefRowNames, RowNames,  [],  []},...
                                        [1,2], ...
                                        {'From', 'To'}, ...
                                        CovarianceFile, ...
                                        hFig, ...
                                        [], ...
                                        1,...
                                        '',...
                                        '');
    
    % Reload call
    ReloadCall = {'view_covariance', CovarianceFile, Modality, hFig};
    setappdata(hFig, 'ReloadCall', ReloadCall);
    
    % Close progress bar and return
    bst_progress('stop');
end