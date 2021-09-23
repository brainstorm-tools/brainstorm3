function outStructs = db_convert_anatomyfile(inStructs, type)
% Bidirectional conversion between Old and New structures
%
% New to Old
% sAnatomy / sSurface = db_convert_anatomyfile(sAnatomyFile)
% 
% Old to New
% sAnatomyFile = db_convert_anatomyfile(sAnatomy, 'anatomy')
% sAnatomyFile = db_convert_anatomyfile(sSurface, 'surface')

% Validate 'type' argument
if ~exist('type','var') || isempty(type)
    type = '';
end

nStructs = length(inStructs);

if nStructs < 1
    outStructs = [];
    return
end 

% Verify the sense of the conversion
% New to old
if all(isfield(inStructs(1), {'Id', 'Type'})) 
    outStructs = repmat(db_template(inStructs(1).Type), 1, nStructs);
    for iStruct = 1 : nStructs 
        % Common fields
        outStructs(iStruct).FileName = inStructs(iStruct).FileName;
        outStructs(iStruct).Comment  = inStructs(iStruct).Name;
        % Extra fields
        if strcmpi(inStructs(iStruct).Type, 'surface')
            outStructs(iStruct).SurfaceType = inStructs(iStruct).SurfaceType;    
        end
    end
    
% Old to new    
else 
    outStructs = repmat(db_template('AnatomyFile'), 1, nStructs);
    for iStruct = 1 : nStructs
        % Common fields
        outStructs(iStruct).FileName = inStructs(iStruct).FileName;
        outStructs(iStruct).Name     = inStructs(iStruct).Comment;
        outStructs(iStruct).Type     = type;
        % Extra fileds
        switch lower(type)
            case 'anatomy'
            % No extra fields
            case 'surface'
            outStructs(iStruct).SurfaceType = inStructs(iStruct).SurfaceType;
            otherwise
            error('Unsupported input structure type');
        end
    end
end