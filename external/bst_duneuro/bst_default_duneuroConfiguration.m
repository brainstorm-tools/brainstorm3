function cfg = bst_default_duneuroConfiguration(varargin)
% cfg = bst_load_default_duneuroConfiguration(cfg);
% This function will load or update the default duneuro values for the configuration file.
% If there is an argument, this function will complete the cfg otherwise it
% will create new structure with default parameters.

% Takfarinas MEDANI


if nargin == 0
    cfg = [];
else
    cfg = varargin{1};
end
    
    
if ~isfield(cfg,'dnFemMethodType'); cfg.dnFemMethodType = 'fitted'; end % 'fitted' or 'unfitted'
if ~isfield(cfg,'dnFemSolverType'); cfg.dnFemSolverType = 'cg'; end % 'fitted' or 'unfitted'
if ~isfield(cfg,'dnMeshElementType'); cfg.dnMeshElementType = 'tetrahedron'; end %  'tetrahedron' or  'hexahedron'
if ~isfield(cfg,'dnGeometryAdapted'); cfg.dnGeometryAdapted = 'false'; end %  'true' or  'false'
if ~isfield(cfg,'dnTolerance'); cfg.dnTolerance = 1e-8; end %  
if ~isfield(cfg,'dnElectrodType'); cfg.dnElectrodType = 'normal'; end %  
if ~isfield(cfg,'dnSolverSolverType'); cfg.dnSolverSolverType ='cg'; end %  what are the others 
if ~isfield(cfg,'dnSolverPreconditionerType'); cfg.dnSolverPreconditionerType = 'amg'; end %  what are the others 
if ~isfield(cfg,'dnSolverCgSmootherType'); cfg.dnSolverCgSmootherType = 'ssor'; end %  what are the others 
if ~isfield(cfg,'dnSolverIntorderadd'); cfg.dnSolverIntorderadd = 0; end %  what are the others 
if ~isfield(cfg,'femSourceModel'); cfg.femSourceModel = 'venant'; end % partial_integration, venant, subtraction | expand smtype
if ~isfield(cfg,'dnSolutionPostProcess'); cfg.dnSolutionPostProcess =  'true'; end
if ~isfield(cfg,'dnSolutionSubstractMean'); cfg.dnSolutionSubstractMean =  'false'; end
if ~isfield(cfg,'dnSolutionSolverReduction'); cfg.dnSolutionSolverReduction = 1e-10; end

end