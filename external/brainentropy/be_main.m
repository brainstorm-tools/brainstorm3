function [varargout] = be_main(varargin)
% BE_MAIN calls the BEst package for solving inverse problems using the MEM 
% algorithm inside Brainstorm
%
% OPTIONS.
% 
% Inputs:
% -------
%
%	HeadModel	:	structure of HeadModel used in brainstorm
%   OPTIONS     :   structure (see bst_sourceimaging.m)
%
%
% Outputs:
% --------
%
%   OPTIONS     :   Updated options fields
%
%   Results     :   structure containing the inverse solution data stored in
%                   brainstorm format.
%
% -------------------------------------------------------------------------
%
% LATIS team, 2012
%
% ==============================================
% License 
%
% BEst is free software: you can redistribute it and/or modify
%    it under the terms of the GNU General Public License as published by
%    the Free Software Foundation, either version 3 of the License, or
%    (at your option) any later version.
%
%    BEst is distributed in the hope that it will be useful,
%    but WITHOUT ANY WARRANTY; without even the implied warranty of
%    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%    GNU General Public License for more details.
%
%    You should have received a copy of the GNU General Public License
%    along with BEst. If not, see <http://www.gnu.org/licenses/>.
% -------------------------------------------------------------------------
%%

% ====      GET DEFAULT OPTIONS      ==== %
Def_OPTIONS     =   BEst_defaults;

% If no arguments: return default options as a result
if numel(varargin) == 0
    varargout{1}        =   Def_OPTIONS;
    return
end

% ====      CALL THE PACKAGE      ==== %
if nargout==1
    % No calculations, just options
    Results             =   be_main_call(varargin{:});
    varargout{1}        =   Results;
else
    % Calculations
    [Results, OPTIONS]  =   be_main_call(varargin{:});
    varargout{1}        =   Results;
    varargout{2}        =   OPTIONS;
end

return


% ----------------------------------------------------------------------- %
% ------------------         NESTED FUNCTIONS          ------------------ %
% ----------------------------------------------------------------------- %

function Def_OPTIONS=   BEst_defaults

% ===== common I/O arguments ===== %%

% Mandatory 
Def_OPTIONS.mandatory.pipeline                  = '';
Def_OPTIONS.mandatory.DataTypes                 = {'MEG'};
Def_OPTIONS.mandatory.ChannelTypes              = {};
Def_OPTIONS.mandatory.DataTime                  = [];
Def_OPTIONS.mandatory.Data                      = [];

% Optional
Def_OPTIONS.optional.verbose                    = 1;
Def_OPTIONS.optional.display                    = 0;  
Def_OPTIONS.optional.iData                      = [];
Def_OPTIONS.optional.Baseline                   = [];
Def_OPTIONS.optional.BaselineTime               = [];
Def_OPTIONS.optional.BaselineChannels           = [];
Def_OPTIONS.optional.BaselineHistory            = [];
Def_OPTIONS.optional.EmptyRoom_data             = [];
Def_OPTIONS.optional.EmptyRoom_channels         = {};
%Def_OPTIONS.optional.normalization              = 'adaptive'; % either 'fixed' or 'adaptive'
Def_OPTIONS.optional.TimeSegment                = [-9999 9999];
Def_OPTIONS.optional.BaselineSegment            = [-9999 9999];
Def_OPTIONS.optional.groupAnalysis              = 0;
Def_OPTIONS.optional.Channel                    = [];
Def_OPTIONS.optional.ChannelFlag                = [];
Def_OPTIONS.optional.FileType                   = '';
Def_OPTIONS.optional.ChannelNames               = '';
Def_OPTIONS.optional.ChannelFlags               = '';
Def_OPTIONS.optional.waitbar                    = 0;
Def_OPTIONS.optional.DataFile                   = '';
Def_OPTIONS.optional.ResultFile                 = '';
Def_OPTIONS.optional.HeadModelFile              = '';
Def_OPTIONS.optional.MSP_min_window             = 11;
Def_OPTIONS.optional.clustering.clusters        = []; % WILL BECOME OBSOLETE and replaced with
%Def_OPTIONS.optional.clustering                = struct; 
% this is the new struture with .clusters (labelling); .initial_alpha ; .sigma; .mu
% (empty at the begining but updated along the code, 
% sigma will be the true smoothing matrix on the patches)

% Automatic (contains the outputs)
Def_OPTIONS.automatic.InverseMethod             = ['MEM (' version ')'];
Def_OPTIONS.automatic.stand_alone               = 0;
Def_OPTIONS.automatic.process                   = 0;
Def_OPTIONS.automatic.Units                     = struct;
Def_OPTIONS.automatic.MEMexpert                 = 0;
Def_OPTIONS.automatic.GoodChannel               = [];
Def_OPTIONS.automatic.sampling_rate             = 0;
Def_OPTIONS.automatic.Modality                  = struct;
Def_OPTIONS.automatic.iData                     = [];
Def_OPTIONS.automatic.final_alpha               = [];
Def_OPTIONS.automatic.entropy_drops             = [];
Def_OPTIONS.automatic.BaselineType              = 'data';
Def_OPTIONS.automatic.iProtocol                 = [];
Def_OPTIONS.automatic.iStudy                    = [];
Def_OPTIONS.automatic.iItem                     = [];
Def_OPTIONS.automatic.DataInfo                  = struct;
Def_OPTIONS.automatic.Comment                   = '';
Def_OPTIONS.automatic.TFcomment                 = 'Wavelet T-F plane - type ''be_vizr'' to display';
Def_OPTIONS.automatic.version                   = 'unknown';        
Def_OPTIONS.automatic.last_update               = 'unknown';

% clustering (parcellization parameters)
Def_OPTIONS.clustering.MSP_R2_threshold         = .95;
Def_OPTIONS.clustering.neighborhood_order       = 4;                       
Def_OPTIONS.clustering.MSP_window               = 10;
Def_OPTIONS.clustering.clusters_type            = 'static';
Def_OPTIONS.clustering.MSP_scores_threshold     = 0;

% MEM model (reference law)
Def_OPTIONS.model.active_mean_method            = 2;
Def_OPTIONS.model.alpha_method                  = 3; 
Def_OPTIONS.model.alpha_threshold               = 0;
Def_OPTIONS.model.initial_lambda                = 1;

% MEM solver
Def_OPTIONS.solver.NoiseCov                     = [];
Def_OPTIONS.solver.NoiseCov_method              = 2;
Def_OPTIONS.solver.NoiseCov_recompute           = 1;
Def_OPTIONS.solver.spatial_smoothing            = 0.6;
Def_OPTIONS.solver.active_var_mult              = 0.05;
Def_OPTIONS.solver.inactive_var_mult            = 0;
Def_OPTIONS.solver.Optim_method                 = 'fminunc';
Def_OPTIONS.solver.covariance_scale             = 1;
Def_OPTIONS.solver.parallel_matlab              = false;

return

