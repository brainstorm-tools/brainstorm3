classdef NwbFile < types.core.NWBFile
    % NWBFILE Root object representing data read from an NWB file.
    %
    % Requires that core and extension NWB types have been generated
    % and reside in a 'types' package on the matlab path.
    %
    % Example. Construct an object from scratch for export:
    %    nwb = NwbFile;
    %    nwb.epochs = types.core.Epochs;
    %    nwbExport(nwb, 'epoch.nwb');
    %
    % See also NWBREAD, GENERATECORE, GENERATEEXTENSION
    
    methods
        function obj = NwbFile(varargin)
            obj = obj@types.core.NWBFile(varargin{:});
        end
        
        function export(obj, filename)
            %add to file create date
            current_time = datetime('now', 'TimeZone', 'local');
            if isa(obj.file_create_date, 'types.untyped.DataStub')
                obj.file_create_date = obj.file_create_date.load();
            end

            if isempty(obj.file_create_date)
                obj.file_create_date = current_time;
            elseif iscell(obj.file_create_date)
                obj.file_create_date(end+1) = {current_time};
            else
                obj.file_create_date = {obj.file_create_date current_time};
            end
            
            %equate reference time to session_start_time if empty
            if isempty(obj.timestamps_reference_time)
                obj.timestamps_reference_time = obj.session_start_time;
            end
            
            try
                output_file_id = H5F.create(filename);
            catch ME % if file exists, open and edit
                isLibraryError = strcmp(ME.identifier,...
                    'MATLAB:imagesci:hdf5lib:libraryError');
                isFileExistsError = isLibraryError &&...
                    contains(ME.message, '''File exists''');
                if isFileExistsError
                    output_file_id = H5F.open(filename, 'H5F_ACC_RDWR', 'H5P_DEFAULT');
                else
                   rethrow(ME); 
                end
            end
            
            try
                obj.embedSpecifications(output_file_id);
                refs = export@types.core.NWBFile(obj, output_file_id, '/', {});
                obj.resolveReferences(output_file_id, refs);
                H5F.close(output_file_id);
            catch ME
                obj.file_create_date(end) = [];
                H5F.close(output_file_id);
                rethrow(ME);
            end
        end
        
        function o = resolve(obj, path)
            if ischar(path)
                path = {path};
            end
            o = cell(size(path));
            for i = 1:numel(path)
                o{i} = io.resolvePath(obj, path{i});
            end
            if isscalar(o)
                o = o{1};
            end
        end
    end
    
    %% PRIVATE
    methods(Access=private)
        function resolveReferences(obj, fid, references)
            while ~isempty(references)
                resolved = false(size(references));
                for iRef = 1:length(references)
                    refSource = references{iRef};
                    sourceObj = obj.resolve(refSource);
                    unresolvedRefs = sourceObj.export(fid, refSource, {});
                    exportSuccess = isempty(unresolvedRefs);
                    resolved(iRef) = exportSuccess;
                end
                
                if any(resolved)
                    references(resolved) = [];
                else
                    errorFormat =...
                        'Could not resolve paths for the following reference(s):\n%s';
                    unresolvedRefs = strjoin(references, newline);
                    error(errorFormat, file.addSpaces(unresolvedRefs, 4));
                end
            end
        end
        
        function embedSpecifications(~, fid)
            try
                attrId = H5A.open(fid, '/.specloc');
                specLocation = H5R.get_name(fid, 'H5R_OBJECT', H5A.read(attrId));
                H5A.close(attrId);
            catch
                specLocation = '/specifications';
                io.writeGroup(fid, specLocation);
                specView = types.untyped.ObjectView(specLocation);
                io.writeAttribute(fid, '/.specloc', specView);
            end

            JsonData = schemes.exportJson();
            for iJson = 1:length(JsonData)
                JsonDatum = JsonData(iJson);
                schemaNamespaceLocation = strjoin({specLocation, JsonDatum.name}, '/');
                namespaceExists = io.writeGroup(fid, schemaNamespaceLocation);
                if namespaceExists
                    namespaceGroupId = H5G.open(fid, schemaNamespaceLocation);
                    names = getVersionNames(namespaceGroupId);
                    H5G.close(namespaceGroupId);
                    for iNames = 1:length(names)
                        H5L.delete(fid, [schemaNamespaceLocation '/' names{iNames}],...
                            'H5P_DEFAULT');
                    end
                end
                schemaLocation =...
                    strjoin({schemaNamespaceLocation, JsonDatum.version}, '/');
                io.writeGroup(fid, schemaLocation);
                Json = JsonDatum.json;
                schemeNames = keys(Json);
                for iScheme = 1:length(schemeNames)
                    name = schemeNames{iScheme};
                    path = [schemaLocation '/' name];
                    io.writeDataset(fid, path, Json(name));
                end
            end
            
            function versionNames = getVersionNames(namespaceGroupId)
                [~, ~, versionNames] = H5L.iterate(namespaceGroupId,...
                    'H5_INDEX_NAME', 'H5_ITER_NATIVE',...
                    0, @removeGroups, {});
                function [status, versionNames] = removeGroups(~, name, versionNames)
                    versionNames{end+1} = name;
                    status = 0;
                end
            end
        end
    end
end
