function savesnirf(data, outfile,varargin)
%
%    savesnirf(snirfdata, fname)
%       or
%    savesnirf(snirfdata, fname, 'Param1',value1, 'Param2',value2,...)
%
%    Load an HDF5 based SNIRF file, and optionally convert it to a JSON 
%    file based on the JSNIRF specification:
%    https://github.com/NeuroJSON/jsnirf
%
%    author: Qianqian Fang (q.fang <at> neu.edu)
%
%    input:
%        snirfdata: a raw SNIRF data, preprocessed SNIRF data or JSNIRF
%             data (root object must be SNIRFData)
%        fname: the output SNIRF (.snirf) or JSNIRF data file name (.jnirs, .bnirs)
%
%    output:
%        data: a MATLAB structure with the grouped data fields
%
%    example:
%        data=loadsnirf('test.snirf');
%        savesnirf(data,'newfile.snirf');
%
%    this file is part of JSNIRF specification: https://github.com/NeuroJSON/jsnirf
%
%    License: GPLv3 or Apache 2.0, see https://github.com/NeuroJSON/jsnirf for details
%

if(nargin<2 || ~ischar(outfile))
    error('you must provide data and a file name');
end

opt=varargin2struct(varargin{:});
if(~isfield(opt,'root'))
    opt.rootname='';
end

if(isfield(data,'SNIRFData'))
    data.nirs=data.SNIRFData;
    data.formatVersion=data.SNIRFData.formatVersion;
    data.nirs=rmfield(data.nirs,'formatVersion');
    data=rmfield(data,'SNIRFData');
end

if(~isempty(outfile))
    if(~isempty(regexp(outfile,'\.[Hh]5$', 'once'))) 
        saveh5(data,outfile,opt);
    elseif(~isempty(regexp(outfile,'\.[Ss][Nn][Ii][Rr][Ff]$', 'once')))
        data.nirs.data=forceindex(data.nirs.data,'measurementList');
        data.nirs=forceindex(data.nirs,'data');
        data.nirs=forceindex(data.nirs,'stim');
        data.nirs=forceindex(data.nirs,'aux');
        saveh5(data,outfile,opt);
    elseif(~isempty(regexp(outfile,'\.[Jj][Nn][Ii][Rr][Ss]$', 'once'))|| ~isempty(regexp(outfile,'\.[Jj][Ss][Oo][Nn]$', 'once')))
        savejson('SNIRFData',data,'FileName',outfile,opt);
    elseif(regexp(outfile,'\.[Mm][Aa][Tt]$'))
        save(outfile,'data');
    elseif(regexp(outfile,'\.[Bb][Nn][Ii][Rr][Ss]$'))
        savebj('SNIRFData',data,'FileName',outfile,opt);
    else
        error('only support .snirf, .h5, .jnirs, .bnirs and .mat files');
    end
end

% force adding index 1 to the group name for singular struct and cell
function newroot=forceindex(root,name)
newroot=root;
fields=fieldnames(newroot);
idx=find(ismember(fields,name));
if(~isempty(idx) && length(newroot.(name))==1)
    newroot.(sprintf('%s1',name))=newroot.(name);
    newroot=rmfield(newroot,name);
    fields{idx(1)}=sprintf('%s1',name);
    newroot=orderfields(newroot,fields);
end

