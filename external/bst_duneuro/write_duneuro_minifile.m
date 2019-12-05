function write_duneuro_minifile(cfg, mini_filename)
%  write_duneuro_minifile(minifile_data)
%  write_duneuro_minifile(minifile_data, output_filename)
% This funcition write in a text file with all the confuguration (initialisation) parameters
% that will be used by the Duneuro application to compute the FEM solution
% The input is a structure that contains the parameters and the output is a
% file with *.mini extention.
% The name of the saved file is  output_filename if specified,
% if not, this function will use the name included in the
% minifile_data.name.
% ex : output_filename = 'myMiniFile.mini'
% This function is limited for the CG at this time
% Dependencies : nothing
%
% August 28, 2019, file created by Takfarinas MEDANI

%% ==> write/adapt the mini file for the other modalities EEG/MEG and fem method : cg, uscg ...

%% Check the input arguments
minifile =  cfg.minifile;

if ~isstruct(cfg)
    error(['The format of ' inputname(1) ' is not correct, it should be a structure... check the help' ])
end

if nargin == 1
    minifile_name = cfg.mini_filename;
else
    minifile_name = mini_filename;
end

% Check the solver type :
if ~strcmp(minifile.solver_type,'cg')
    error (['solver_type : "' vol.minifile.solver_type  '"  this function is not adapted for this format ... we work on it' ])
end

% check if the extention is included 
[filepath,name,ext] = fileparts(minifile_name);
if isempty(ext)
    minifile_name = [minifile_name '.mini'];
end

%minifile = vol.cfg.minifile;
%% Write the mini file
fid = fopen(minifile_name, 'wt+');
% subpart general setting
fprintf(fid, '__name = %s\n',minifile.name);
fprintf(fid, 'type = %s\n',minifile.type);
fprintf(fid, 'solver_type = %s\n',minifile.solver_type);
fprintf(fid, 'element_type  =%s\n',minifile.element_type );
fprintf(fid, 'geometry_adapted  = %s\n',minifile.geometry_adapted);
fprintf(fid, 'tolerance = %d\n',minifile.tolerance);
% subpart electrode : [electrodes]
fprintf(fid, '[electrodes]\n');
fprintf(fid, 'filename  = %s\n',minifile.electrode.filename);
fprintf(fid, 'type = %s\n',minifile.electrode.type);
% subpart electrode : [dipoles]
fprintf(fid, '[dipoles]\n');
fprintf(fid, 'filename  = %s\n',minifile.dipole.filename);
% subpart [volume_conductor.grid]
fprintf(fid, '[volume_conductor.grid]\n');
fprintf(fid, 'filename  = %s\n',minifile.volume_conductor_grid.filename);
% subpart  [volume_conductor.tensors]
fprintf(fid, '[volume_conductor.tensors]\n');
fprintf(fid, 'filename  = %s\n',minifile.volume_conductor_tensors.filename);
% subpart  [solver]
fprintf(fid, '[solver]\n');
fprintf(fid, 'solver_type  = %s\n',minifile.solver.solver_type);
fprintf(fid, 'preconditioner_type  = %s\n',minifile.solver.preconditioner_type);
fprintf(fid, 'cg_smoother_type  = %s\n',minifile.solver.cg_smoother_type);
fprintf(fid, 'intorderadd  = %d\n',minifile.solver.intorderadd);
% subpart  [solution]
fprintf(fid, '[solution]\n');
fprintf(fid, 'post_process  = %s\n',minifile.solution.post_process);
fprintf(fid, 'subtract_mean  = %s\n',minifile.solution.subtract_mean);
% subpart  [solution.solver]
fprintf(fid, '[solution.solver]\n');
fprintf(fid, 'reduction  = %d\n',minifile.solution.solver.reduction);
% subpart  [solution.source_model]
fprintf(fid, '[solution.source_model]\n');
fprintf(fid, 'type  = %s\n',minifile.solution.source_model.type );
fprintf(fid, 'intorderadd  = %d\n',minifile.solution.source_model.intorderadd);
fprintf(fid, 'intorderadd_lb  = %d\n',minifile.solution.source_model.intorderadd_lb);
fprintf(fid, 'numberOfMoments  = %d\n',minifile.solution.source_model.numberOfMoments);
fprintf(fid, 'referenceLength  = %d\n',minifile.solution.source_model.referenceLength);
fprintf(fid, 'weightingExponent  = %d\n',minifile.solution.source_model.weightingExponent );
fprintf(fid, 'relaxationFactor  = %d\n',minifile.solution.source_model.relaxationFactor);
fprintf(fid, 'mixedMoments  = %s\n',minifile.solution.source_model.mixedMoments);
fprintf(fid, 'restrict  = %s\n',minifile.solution.source_model.restrict );
fprintf(fid, 'initialization  = %s\n',minifile.solution.source_model.initialization);
% The reste is not needed... just in case for further use
% subpart [analytic_solution]
fprintf(fid, '[analytic_solution]\n');
Nb_Layer = length(minifile.solution.analytic_solution.radii);
fprintf(fid, 'radii =\t');
for ind = 1 : Nb_Layer
    fprintf(fid, '%d \t', minifile.solution.analytic_solution.radii(ind));
end
fprintf(fid, '\n');
fprintf(fid, 'center =\t');
for ind = 1 : 3
    fprintf(fid, '%d \t', minifile.solution.analytic_solution.center(ind));
end
fprintf(fid, '\n');
fprintf(fid, 'conductivities =\t');
for ind = 1 : Nb_Layer
    fprintf(fid, '%d \t', minifile.solution.analytic_solution.conductivities(ind));
end
fprintf(fid, '\n');
% subpart  [output]
fprintf(fid, '[output]\n');
fprintf(fid, 'filename  = %s\n',minifile.output.filename);
fprintf(fid, 'extension  = %s\n',minifile.output.extension);
% subpart [wrapper.outputtreecompare]
fprintf(fid, '[wrapper.outputtreecompare]\n');
fprintf(fid, 'name  = %s\n',minifile.wrapper.outputtreecompare.name);
fprintf(fid, 'extension  = %s\n',minifile.wrapper.outputtreecompare.extension);
fprintf(fid, 'reference  = %s\n',minifile.wrapper.outputtreecompare.reference);
fprintf(fid, 'type  = %s\n',minifile.wrapper.outputtreecompare.type);
fprintf(fid, 'absolute  = %d\n',minifile.wrapper.outputtreecompare.absolute);
fclose(fid);
end
