function cfg = bst_duneuro_interface(cfg)
% BST_DUNEURO_INTERFACE : Writes the arguments from bst to duneuro and run the FEM
%
% USAGE:      cfg = bst_duneuro_interface(cfg)
%
% INPUT:
%     - cfg: structure with the fields:
%              Run the example\demo  in order to have the full liste 
% @=============================================================================
% This function is part of the Brainstorm software:
% https://neuroimage.usc.edu/brainstorm
%
% Copyright (c)2000-2019 University of Southern California & McGill University
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
% Authors: Takfarinas MEDANI, December 2019; 

% Set the default parameters used in this function
if ~isfield(cfg,'runFromBst'); cfg.runFromBst = 0; end                    % Works only if called from brainstorm (also if brainstorm is in the path)
if ~isfield(cfg,'currentPath'); cfg.currentPath = pwd; end                 % This function will cd to a temporary file and then return here (pwd) 
if ~isfield(cfg,'useTransferMatrix'); cfg.useTransferMatrix = 1; end % use the transfer matrix is recommended ( choice 0 only for duneuroVersion 1)
if ~isfield(cfg,'isotrop'); cfg.BstDuneuroVersion = 1; end                 % 1 previous with separate files, 2the new version combined eeg and meg and binary + txt output,   
if ~isfield(cfg,'isotrop'); cfg.isotrop =1; end                                       % important to specify in order to write the correct file format (1 will use MSH, 0 will use Cauchy)
if ~isfield(cfg,'lfAvrgRef'); cfg.lfAvrgRef = 0; end                              %  compute average reference 1, otherwise the electrode 1 is the reference and set to 0
if ~isfield(cfg,'displayComment'); cfg.displayComment  = 0; end
if cfg.runFromBst ==  1;  cfg.lfAvrgRef = 0; end                               % It seems that brainstorm has its own procedure, in that case the for duneuro the electrod 1 is the reference and set to 0 

cfg.displayComment = 1;
cfg.BstDuneuroVersion = 2;

%% 0 - Copy the binaries output directory
if cfg.runFromBst == 1; bst_progress('text', ['Duneuro: copying the binaries to the  ' fullfile(cfg.pathOfTempOutPut)]); end
if cfg.displayComment ==1; disp(['duneruo >>0 - Changing path from ' cfg.currentPath ' to ' (fullfile(cfg.pathOfTempOutPut))]);end
copyfile(fullfile(cfg.pathOfDuneuroToolbox,'bin','*'),(fullfile(cfg.pathOfTempOutPut)),'f')
cd(fullfile(cfg.pathOfTempOutPut));

%% 1- The head model
% Write the head file according to the configuration cfg
if cfg.runFromBst == 1; bst_progress('text', 'Duneuro:  write the head geometry file ... '); end
if cfg.displayComment ==1;disp(['duneruo >>1 - Writing the head file  to ' ((cfg.pathOfTempOutPut))]);end
if ~isfield(cfg,'filename'); cfg.filename = 'head_model'; end  % Use the default name.
cfg = bst_prepare_head_model(cfg);

%% 2- The Source Model 
% Write the source/dipole file
if cfg.runFromBst == 1; bst_progress('text', 'Duneuro:  write the dipoles file ... '); end
if cfg.displayComment ==1;disp(['duneruo >>2 - Writing the dipole file  to ' ((cfg.pathOfTempOutPut))]);end
cfg.dipole_filename  = 'dipole_model.txt';
write_duneuro_dipole_file(cfg.sourceSpace,cfg.dipole_filename);

%% 3- The electrode Model
if cfg.runFromBst == 1; bst_progress('text', 'Duneuro:  write the electrode file ... '); end
if cfg.displayComment ==1;disp(['duneruo >>3 - Writing the electrode  file  to ' ((cfg.pathOfTempOutPut))]);end
cfg.electrode_filename = 'electrode_model.txt';
write_duneuro_electrode_file(cfg.channelLoc, cfg.electrode_filename);

%% 4- The Conductivity Model
if cfg.runFromBst == 1; bst_progress('text', 'Duneuro:  write the conductivity file ... '); end
if cfg.displayComment ==1;disp(['duneruo >>4 - Writing the conductivity/tensor file  to ' ((cfg.pathOfTempOutPut))]);end
cfg = bst_prepare_conductivity_model(cfg);

%%  5- The Duneuro Configuration file / the minifile
if cfg.runFromBst == 1; bst_progress('text', 'Duneuro:  write the configuration file ... '); end
if cfg.displayComment ==1;disp(['duneruo >>5 - Writing the duneuro configuration file  to ' ((cfg.pathOfTempOutPut))]);end
cfg = bst_prepare_minifile(cfg);

%% 6- Run the duneuro
if cfg.runFromBst == 1; bst_progress('text', 'Duneuro:  run fem computation ... '); end
if cfg.displayComment ==1;disp(['duneruo >>6 - Run duneuro binaries from ' (fullfile(cfg.pathOfTempOutPut))]);end
% define the command line
cfg = bst_set_duneuro_cmd(cfg);

% run Duneuro
% tic; cfg = bst_run_duneuro_cmd(cfg); time_fem = toc
cfg = bst_run_duneuro_cmd(cfg);
if cfg.displayComment ==1;disp(['duneruo >>6 - Run duneuro binaries from ' (fullfile(cfg.pathOfTempOutPut)) '... finished']);end

%% 7- Read the lead field matrix
if cfg.displayComment ==1;disp(['duneuro >>7 - Read the leadfield from ' (fullfile(cfg.pathOfTempOutPut))]);end
cfg = bst_read_duneuro_leadfield(cfg);

%% substract the mean or not from the electrode
if cfg.displayComment ==1;disp('duneuro >>8 - Postprocess the  leadfield ');end
%TODO : check the minifile parameters and adapt this code
if cfg.lfAvrgRef == 1
    if cfg.useTransferMatrix == 1
        if sum(cfg.lf_fem(1,:)) == 0
            disp('Transforming from elec1 reference to average reference');
            cfg.lf_fem  = cfg.lf_fem  - (mean(cfg.lf_fem,1));
        else
            disp('The average reference is the output of duneuro, please check the mini file');
        end    
    end
end

%% remove the temporary folder
if cfg.displayComment ==1;disp(['duneruo >>9 - Clean the folder  ' (fullfile(cfg.pathOfTempOutPut))]);end
if ~isfield(cfg,'deleteOutputFolder'); cfg.deleteOutputFolder = 0; end
if cfg.deleteOutputFolder == 1
    % TODO or leave bst to do it
    disp(['remove the '  (fullfile(cfg.pathOfTempOutPut)) ' from the hard disc']);
end

%% go back to the work space
if cfg.displayComment ==1;disp(['duneruo >>10 - Going back to  ' cfg.currentPath ]);end
cd(cfg.currentPath)

if ~isfield(cfg,'writeLogFile'); cfg.writeLogFile = 0; end
if cfg.writeLogFile == 1; diary off; end
end