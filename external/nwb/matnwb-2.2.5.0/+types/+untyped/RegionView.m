classdef RegionView < handle
    properties(SetAccess=private)
        path;
        view;
        region;
    end
    
    properties(Constant,Hidden)
        type = 'H5T_STD_REF_DSETREG';
        reftype = 'H5R_DATASET_REGION';
    end
    
    methods
        function obj = RegionView(path, region, datasize)
            %REGIONVIEW A region reference to a dataset in the same nwb file.
            % obj = REGIONVIEW(path, region)
            % path = char representing the internal path to the dataset.
            % region = cell array whose contents are a 2xn array of bounds where n is
            %   the subscript size
            obj.view = types.untyped.ObjectView(path);
            assert(isreal(region) || ...
                (iscell(region) && all(cellfun('isreal', region))),...
                'RegionView only accepts either numeric indices or cell array of bounds');
            if isreal(region)
                if nargin > 2
                    region = misc.idx2h5(region, datasize);
                else
                    region = misc.idx2h5(region);
                end
            elseif any(cellfun('size', region, 1) ~= 2)
                assert(all(cellfun('size', region, 2) == 2),...
                    'RegionView expects exactly 2 rows of index bounds per cell.');
                for i=1:length(region)
                    region{i} = region{i} .';
                end
            end
            
            obj.region = region;
        end
        
        %given an sid, this region will return that sid but with the
        %correct selection parameters
        function sid = get_selection(obj, sid)
            H5S.select_none(sid);
            for i=1:length(obj.region)
                reg = obj.region{i};
                H5S.select_hyperslab(sid, 'H5S_SELECT_OR', reg(1,:),...
                    [], [], diff(reg, 1, 1)+1);
            end
        end
        
        function view = refresh(obj, Nwb)
            %REFRESH follows references and loads data to memory
            %   DATA = REFRESH(NWB) returns the data defined by the RegionView.
            %   NWB is the nwb object returned by nwbRead.
            
            view = cell(size(obj));
            for i = 1:numel(obj)
                view{i} = scalar_refresh(obj(i), Nwb);
            end
            
            if isscalar(view)
                view = view{1};
            end
            
            function v = scalar_refresh(RegionView, Nwb)
                if isempty(RegionView.region)
                    v = [];
                    return;
                end
                
                Object = RegionView.view.refresh(Nwb);
                
                if isa(Object.data, 'types.untyped.DataStub')
                    sid = RegionView.get_selection(Object.data.get_space());
                    v = Object.data.load_h5_style(sid);
                    H5S.close(sid);
                else
                    v = Object.data;
                end
                
                % convert 0-indexed subscript bounds to 1-indexed linear indices.
                bsizes = zeros(length(RegionView.region),1);
                boundLIdx = cell(length(RegionView.region),1);
                for iRegions = 1:length(RegionView.region)
                    region = RegionView.region{iRegions} + 1;
                    region = mat2cell(region, 2, ones(1, size(region, 2)));
                    boundLIdx{iRegions} = sub2ind(size(v), region{end:-1:1});
                    bsizes(iRegions) = diff(boundLIdx{iRegions}, 1, 1) + 1;
                end
                
                lIdx = zeros(sum(bsizes), 1);
                for iReferenced = 1:length(boundLIdx)
                    idx = sum(bsizes(1:iReferenced-1)) + 1;
                    lIdx(idx:bsizes(iReferenced)) =...
                        (boundLIdx{iReferenced}(1):boundLIdx{iReferenced}(2)) .';
                end
                
                if istable(v)
                    v = v(lIdx, :); % tables only take 2d indexing
                else
                    v = v(lIdx);
                end
            end
        end
        
        function refs = export(obj, fid, fullpath, refs)
            io.writeDataset(fid, fullpath, class(obj), obj);
        end
        
        function path = get.path(obj)
            path = obj.view.path;
        end
    end
end