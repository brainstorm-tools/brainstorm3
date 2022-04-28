function savesnirf(data, outfile,varargin)
%
%    savesnirf(snirfdata, fname)
%       or
%    savesnirf(snirfdata, fname, 'Param1',value1, 'Param2',value2,...)
%
%    Load an HDF5 based SNIRF file, and optionally convert it to a JSON 
%    file based on the JSNIRF specification:
%    https://github.com/fangq/jsnirf
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
%    this file is part of JSNIRF specification: https://github.com/fangq/jsnirf
%
%    License: GPLv3 or Apache 2.0, see https://github.com/fangq/jsnirf for details
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
    if(~isempty(regexp(outfile,'\.[Hh]5$', 'once')) || ~isempty(regexp(outfile,'\.[Ss][Nn][Ii][Rr][Ff]$', 'once')))
        saveh5(data,outfile,opt);
    elseif(~isempty(regexp(outfile,'\.[Jj][Nn][Ii][Rr][Ss]$', 'once'))|| ~isempty(regexp(outfile,'\.[Jj][Ss][Oo][Nn]$', 'once')))
        savejson('SNIRDData',data,'FileName',outfile,opt);
    elseif(regexp(outfile,'\.[Mm][Aa][Tt]$'))
        save(outfile,'data');
    elseif(regexp(outfile,'\.[Bb][Nn][Ii][Rr][Ss]$'))
        saveubjson('SNIRDData',data,'FileName',outfile,opt);
    else
        error('only support .jnirs,.bnirs and .mat files');
    end
end
