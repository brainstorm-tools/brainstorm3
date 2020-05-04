function varargout=loadh5(filename, varargin)
%
%    [data, meta] = loadh5(filename)
%    [data, meta] = loadh5(root_id)
%    [data, meta] = loadh5(filename, rootpath)
%    [data, meta] = loadh5(filename, rootpath, options)
%    [data, meta] = loadh5(filename, options)
%    [data, meta] = loadh5(filename, 'Param1',value1, 'Param2',value2,...)
%
%    Load data in an HDF5 file to a MATLAB structure.
%
%    author: Qianqian Fang (q.fang <at> neu.edu)
%
%    input
%        filename
%            Name of the file to load data from
%        root_id: an HDF5 handle (of type 'H5ML.id' in MATLAB)
%        rootpath : (optional)
%            Root path to read part of the HDF5 file to load
%        options: (optional) a struct or Param/value pairs for user specified options
%            Order: 'creation' - creation order (default), or 'alphabet' - alphabetic
%            Regroup: [0|1]: if 1, call regrouph5() to combine indexed
%                  groups into a cell array
%            PackHex: [1|0]: convert invalid characters in the group/dataset
%                  names to 0x[hex code] by calling encodevarname.m;
%                  if set to 0, call getvarname
%            ComplexFormat: {'realKey','imagKey'}: use 'realKey' and 'imagKey'
%                  as possible keywords for the real and the imaginary part
%                  of a complex array, respectively (sparse arrays not supported);
%                  a common list of keypairs is used even without this option
%
%    output
%        data: a structure (array) or cell (array)
%        meta: optional output to store the attributes stored in the file
%
%    example:
%        a={rand(2), struct('va',1,'vb','string'), 1+2i};
%        saveh5(a,'test.h5');
%        a2=loadh5('test.h5')
%        a3=loadh5('test.h5','regroup',1)
%        isequaln(a,a3.a)
%        a4=loadh5('test.h5','/a1')
%
%    This function was adapted from h5load.m by Pauli Virtanen <pav at iki.fi>
%    This file is part of EasyH5 Toolbox: https://github.com/fangq/easyh5
%
%    License: GPLv3 or 3-clause BSD license, see https://github.com/fangq/easyh5 for details
%

path = '';
if(bitand(length(varargin),1)==0)
    opt=varargin2struct(varargin{:});
elseif(length(varargin)>=3)
    path=varargin{1};
    opt=varargin2struct(varargin{2:end});
elseif(length(varargin)==1)
    path=varargin{1};
end

if(isa(filename,'H5ML.id'))
    loc=filename;
else
    loc = H5F.open(filename);
end

opt.rootpath=path;

if(~(isfield(opt,'complexformat') && iscellstr(opt.complexformat) && numel(opt.complexformat)==2))
    opt.complexformat={};
end
   
try
  if(nargin>1 && ~isempty(path))
      try
          rootgid=H5G.open(loc,path);
          [varargout{1:nargout}]=load_one(rootgid, opt);
          H5G.close(rootgid);
      catch
          [gname,dname]=fileparts(path);
          rootgid=H5G.open(loc,gname);
          [status, res]=group_iterate(rootgid,dname,struct('data',struct,'meta',struct,'opt',opt));
          if(nargout>0)
              varargout{1}=res.data;
          elseif(nargout>1)
              varargout{2}=res.meta;
          end
          H5G.close(rootgid);
      end
  else
      [varargout{1:nargout}]=load_one(loc, opt);
  end
  H5F.close(loc);
catch ME
  H5F.close(loc);
  rethrow(ME);
end

if(jsonopt('Regroup',0,opt))
    if(nargout>=1)
        varargout{1}=regrouph5(varargout{1});
    elseif(nargout>=2)
        varargout{2}=regrouph5(varargout{2});
    end
end

if(isfield(opt,'jdata') && opt.jdata && nargout>=1)
    varargout{1}=jdatadecode(varargout{1},'Base64',0,opt);
end

%--------------------------------------------------------------------------
function [data, meta]=load_one(loc, opt)

data = struct();
meta = struct();
inputdata=struct('data',data,'meta',meta,'opt',opt);
order='H5_INDEX_CRT_ORDER';
if(isfield(opt,'order') && strcmpi(opt.order,'alphabet'))
   order='H5_INDEX_NAME';
end

% Load groups and datasets
try
    [status,count,inputdata] = H5L.iterate(loc,order,'H5_ITER_INC',0,@group_iterate,inputdata);
catch
    if(strcmp(order,'H5_INDEX_CRT_ORDER'))
        [status,count,inputdata] = H5L.iterate(loc,'H5_INDEX_NAME','H5_ITER_INC',0,@group_iterate,inputdata);
    end
end

data=inputdata.data;
meta=inputdata.meta;

%--------------------------------------------------------------------------
function [status, res]=group_iterate(group_id,objname,inputdata)
status=0;
attr=struct();

encodename=jsonopt('PackHex',1,inputdata.opt);

try
  data=inputdata.data;
  meta=inputdata.meta;

  % objtype index 
  info = H5G.get_objinfo(group_id,objname,0);
  objtype = info.type;
  objtype = objtype+1;
  
  if objtype == 1
    % Group
    name = regexprep(objname, '.*/', '');
  
	group_loc = H5G.open(group_id, name);
	try
	  [sub_data, sub_meta] = load_one(group_loc, inputdata.opt);
	  H5G.close(group_loc);
	catch ME
	  H5G.close(group_loc);
	  rethrow(ME);
	end
	if(encodename)
        name=encodevarname(name);
    else
        name=genvarname(name);
    end
    data.(name) = sub_data;
    meta.(name) = sub_meta;
    
  elseif objtype == 2
    % Dataset
    name = regexprep(objname, '.*/', '');
  
	dataset_loc = H5D.open(group_id, name);
	try
	  sub_data = H5D.read(dataset_loc, ...
	      'H5ML_DEFAULT', 'H5S_ALL','H5S_ALL','H5P_DEFAULT');
          [status, count, attr]=H5A.iterate(dataset_loc, 'H5_INDEX_NAME', 'H5_ITER_INC', 0, @getattribute, attr);
	  H5D.close(dataset_loc);
	catch exc
	  H5D.close(dataset_loc);
	  rethrow(exc);
	end
	
	sub_data = fix_data(sub_data, attr, inputdata.opt);
	if(encodename)
        name=encodevarname(name);
    else
        name=genvarname(name);
    end
    data.(name) = sub_data;
    meta.(name) = attr;
  end
catch ME
    rethrow(ME);
end
res=struct('data',data,'meta',meta,'opt',inputdata.opt);

%--------------------------------------------------------------------------
function data=fix_data(data, attr, opt)
% Fix some common types of data to more friendly form.

if isstruct(data)
  fields = fieldnames(data);

  if(length(intersect(fields,{'SparseIndex','Real'}))==2)
    if isnumeric(data.SparseIndex) && isnumeric(data.Real)
      if(nargin>1 && isstruct(attr))
          if(isfield(attr,'SparseArraySize'))
              spd=sparse(1,prod(attr.SparseArraySize));
              if(isfield(data,'Imag'))
                  spd(data.SparseIndex)=complex(data.Real,data.Imag);
              else
                  spd(data.SparseIndex)=data.Real;
              end
              data=reshape(spd,attr.SparseArraySize(:)');
          end
      end
    end
  end

  if(numel(opt.complexformat)==2 && length(intersect(fields,opt.complexformat))==2)
    if isnumeric(data.(opt.complexformat{1})) && isnumeric(data.(opt.complexformat{2}))
        data = data.(opt.complexformat{1}) + 1j*data.(opt.complexformat{2});
    end
  else
    % if complexformat is not specified or not found, try some common complex number storage formats
    if(length(intersect(fields,{'Real','Imag'}))==2)
      if isnumeric(data.Real) && isnumeric(data.Imag)
        data = data.Real + 1j*data.Imag;
      end
    elseif(length(intersect(fields,{'real','imag'}))==2)
      if isnumeric(data.real) && isnumeric(data.imag)
        data = data.real + 1j*data.imag;
      end
    elseif(length(intersect(fields,{'Re','Im'}))==2)
      if isnumeric(data.Re) && isnumeric(data.Im)
        data = data.Re + 1j*data.Im;
      end
    elseif(length(intersect(fields,{'re','im'}))==2)
      if isnumeric(data.re) && isnumeric(data.im)
        data = data.re + 1j*data.im;
      end
    elseif(length(intersect(fields,{'r','i'}))==2)
      if isnumeric(data.r) && isnumeric(data.i)
        data = data.r + 1j*data.i;
      end
    end
  end
  
end

if(isa(data,'uint8') || isa(data,'int8'))
  if(nargin>1 && isstruct(attr))
      if(isfield(attr,'MATLABObjectClass'))
         data=getArrayFromByteStream(data); % use undocumented function
      end
  end
end

%--------------------------------------------------------------------------
function [status, dataout]= getattribute(loc_id,attr_name,info,datain)
status=0;
attr_id = H5A.open(loc_id, attr_name, 'H5P_DEFAULT');
datain.(attr_name) = H5A.read(attr_id, 'H5ML_DEFAULT');
H5A.close(attr_id);
dataout=datain;
