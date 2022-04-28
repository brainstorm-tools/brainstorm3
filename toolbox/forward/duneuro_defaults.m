function cfg = duneuro_defaults(cfg)
% DUNEURO_DEFAULTS Returns the default configuration for DUNEuro
%
% USAGE:     cfg = duneuro_defaults()       % Return default options
%            cfg = duneuro_defaults(cfg)    % Add missing options to existing cfg structure

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
% Authors: Takfarinas Medani, 2019-2020
%          Francois Tadel, 2020

% Brainstorm-side General options
cfgDef.FemCond          = [];
cfgDef.FemSelect        = [];
cfgDef.UseTensor        = false;
cfgDef.Isotropic        = true;
cfgDef.SrcShrink        = 0;
cfgDef.SrcForceInGM     = false;
% DUNEuro general settings
cfgDef.FemType          = 'fitted';                % 'fitted' or 'unfitted'
cfgDef.SolverType       = 'cg';                    % 'cg' or 'dg'
cfgDef.GeometryAdapted  = false;                   % 'true' or 'false'
cfgDef.Tolerance        = 1e-8;
% [electrodes]
cfgDef.ElecType         = 'normal';
% [meg]
cfgDef.MegIntorderadd   = 0;
cfgDef.MegType          = 'physical';
% [solver]
cfgDef.SolvSolverType   = 'cg';   % 'cg'= conjugate gradient
cfgDef.SolvPrecond      = 'amg';
cfgDef.SolvSmootherType = 'ssor';
cfgDef.SolvIntorderadd  = 0;
cfgDef.DgSmootherType   = 'ssor';
cfgDef.DgScheme         = 'sipg';
cfgDef.DgPenalty        = 20;
cfgDef.DgEdgeNormType   = 'houston';
cfgDef.DgWeights        = true;
cfgDef.DgReduction      = true;
% [solution]
cfgDef.SolPostProcess   = true;
cfgDef.SolSubstractMean = false;
% [solution.solver]
cfgDef.SolSolverReduction = 1e-10;
% [solution.source_model]
cfgDef.SrcModel          = 'venant';  % partial_integration, venant, subtraction
cfgDef.SrcIntorderadd    = 0;
cfgDef.SrcIntorderadd_lb = 2;
cfgDef.SrcNbMoments      = 3;
cfgDef.SrcRefLen         = 20;
cfgDef.SrcWeightExp      = 1;
cfgDef.SrcRelaxFactor    = 6;
cfgDef.SrcMixedMoments   = true;
cfgDef.SrcRestrict       = true;
cfgDef.SrcInit           = 'closest_vertex';
% [brainstorm]
cfgDef.BstSaveTransfer    = false;
cfgDef.BstEegTransferFile = 'eeg_transfer.dat';
cfgDef.BstMegTransferFile = 'meg_transfer.dat';
cfgDef.BstEegLfFile       = 'eeg_lf.dat';
cfgDef.BstMegLfFile       = 'meg_lf.dat';

% [MEG computation Options]
cfgDef.UseIntegrationPoint = 1; 
cfgDef.EnableCacheMemory = 0;
cfgDef.MegPerBlockOfSensor = 0; % ToDo
% Use default values if not set
if (nargin == 0) || isempty(cfg)
    cfg = cfgDef;
    return;
end
% Add missing values
cfg = struct_copy_fields(cfg, cfgDef, 0);



% % The reste is not needed... we keep it just in case
% % subpart [analytic_solution]
% cfg.minifile.solution.analytic_solution.radii = [1 2 3 4 ];
% cfg.minifile.solution.analytic_solution.center = [0 0 0];
% cfg.minifile.solution.analytic_solution.conductivities = [1 0.0125 1 1];
% % subpart  [output]
% cfg.minifile.output.filename = 'ns';
% cfg.minifile.output.extension = 'ns';
% % subpart [wrapper.outputtreecompare]
% cfg.minifile.wrapper.outputtreecompare.name = 'ns';
% cfg.minifile.wrapper.outputtreecompare.extension = 'ns';
% cfg.minifile.wrapper.outputtreecompare.reference = 'ns';
% cfg.minifile.wrapper.outputtreecompare.type = 'ns';
% cfg.minifile.wrapper.outputtreecompare.absolute = 'ns'; %1e-2;

% % [analytic_solution]
% fprintf(fid, '[analytic_solution]\n');
% Nb_Layer = length(cfg.minifile.solution.analytic_solution.radii);
% fprintf(fid, 'radii =\t');
% for ind = 1 : Nb_Layer
%     fprintf(fid, '%d \t', cfg.minifile.solution.analytic_solution.radii(ind));
% end
% fprintf(fid, '\n');
% fprintf(fid, 'center =\t');
% for ind = 1 : 3
%     fprintf(fid, '%d \t', cfg.minifile.solution.analytic_solution.center(ind));
% end
% fprintf(fid, '\n');
% fprintf(fid, 'conductivities =\t');
% for ind = 1 : Nb_Layer
%     fprintf(fid, '%d \t', cfg.minifile.solution.analytic_solution.conductivities(ind));
% end
% fprintf(fid, '\n');
% % subpart  [output]
% fprintf(fid, '[output]\n');
% fprintf(fid, 'filename  = %s\n',cfg.minifile.output.filename);
% fprintf(fid, 'extension  = %s\n',cfg.minifile.output.extension);
% % subpart [wrapper.outputtreecompare]
% fprintf(fid, '[wrapper.outputtreecompare]\n');
% fprintf(fid, 'name  = %s\n',cfg.minifile.wrapper.outputtreecompare.name);
% fprintf(fid, 'extension  = %s\n',cfg.minifile.wrapper.outputtreecompare.extension);
% fprintf(fid, 'reference  = %s\n',cfg.minifile.wrapper.outputtreecompare.reference);
% fprintf(fid, 'type  = %s\n',cfg.minifile.wrapper.outputtreecompare.type);
% fprintf(fid, 'absolute  = %s\n',cfg.minifile.wrapper.outputtreecompare.absolute);




