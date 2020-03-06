function z = xmltools( arg, out_file, varargin)
% XMLTOOLS - tools for managing xml data sets
%      - if arg is a string : arg is an XML file to convert into MATLAB struct
%      - if arg is a variable : it is a MATLAB struct to write into XML, to stdout if out_file is not given
% use :
%  z = xmltools('filename.xml'); read an xml file and store it into z
%  xmltools(z,'filename.xml'); write z into the file
%  xmltools(z,'get','tag-name'); returns only subset of z child which name is tag-name
%  xmltools(z,'get-attrib', 'attrib-name')
%  xmltools(z,'get','tag-name', 'attribs'|'value'|'child');
%
% project 'File parsing'
% title    'XML parsing'
% author  'Charles-Albert Lehalle'
% mailto  'charles.lehalle@miriadtech.com'
% version '2.5'
% date    'mar2003--sept2003'

version = '2.5';

%%** XML TOOLS FOR MATLAB
% This is an OCAMAWEB (http://ocamaweb.sourceforge.net) generated documentation.\\
% This function manage the exchange of data between XML files and a MATLAB structure.
% The MATLAB structure is this : a {\bf node} is a struct with fields {\it tag}, {\it value}, {\it attribs}, {\it child}.
% Where {\it tag} is the tag name, {\it value} its contents, {\it attribs} an array of structure with fields {\it name} and {\it value},
% and {\it child} an array of such nodes.\\
% All those fields are always present and can be empty except for the first node (root) that has only children.\\
%

global Verbose;
Verbose=0;
%%* READ AN XML FILE
if isstr(arg)
  
  %< R�cup�ration du fichier dans un string
  fid = fopen(arg, 'r');
  if fid<0
      error('Pb opening the xml file');
  end
  F = fread(fid);
  s = char(F');
  fclose(fid);
  %>
  
  %< Parsing
  z = parse_xml(s);
  %>
  return
end

if ~isstr(arg)

  %<* SELECT A SUBSET OF z CHILD
  if length(varargin) >= 1 %& ~FileExists(arg)
    
    cmode = upper( out_file);
    z     = arg;
    
    switch upper( cmode)
      
     case 'GET'
      %< Get the subset
      % warning: I will have to change the value of next at some places
      next = 'child';
    
      if ~isfield(z, next)
        error('XMLTOOLS:GET', 'For child selection, structured first argument is needed');
      end
      tag_name = (varargin{1});
      
      z = get_childs(z, next, tag_name);
      %>
      
      %< get values
      % xmltools( z, 'get', 'tag-name', 'attribs'|'value'|'child')
      if length(varargin) == 2
        switch upper( varargin{2})
         case 'VALUE'
          z = [z.value];
         case 'ATTRIBS'
          z = [z.attribs];
         case 'CHILD'
          z = [z.child];
         otherwise
          error('XMLTOOLS:GET', 'get mode <%s> is not defined, use one of <attribs>|<value>|<child>', upper(varargin{2}));
        end
      end
      %>
      
     case 'GET-ATTRIB'
      %< get attrib
      % xmltools(z, 'get-attrib', 'attrib-name')
      s = z.attribs;
      for i=1:length(s)
        if strcmp((s(i).name), ( varargin{1}) )
          z = s(i).value;
          return
        end
      end
      error('XMLTOOLS:GET-ATTRIB', 'no attribute found'); %, varargin{1});
      %>
      
    end
           
    return
  end
  %>*
  
  %<* WRITE AN XML STRUCTURE
  
  %< Selection de la cible
  if nargin < 2
    fid = 1;
  else
    fid = fopen(out_file, 'w');
  end
  %>
  
  %< Ecriture proprement dite
  write_xml(fid, arg, -1);
  %>
  
  %< Fermeture
  if nargin > 1
    fclose(fid);
  end
  %>
  
  %>*
end

%%** Fonctions internes

%<* parser un string xml
function [z, str] = parse_xml( str, current_tag, current_value, attribs, idx)
global Verbose;
next = 'child';

if nargin < 2
  current_tag   = '';
  current_value = '';
  attribs       = '';
  idx           = 0;
end
z = [];

eot = 0;

while ~eot & ~isempty(udeblank(deblank(str)))
  
  f_end = strfind(str, '</');
  f_beg = strfind(str, '<');
  
  %< Si je n'ai plus de tag dans mon document
  if isempty(f_end) & isempty(f_beg)
    
    if ~strcmp(lower(current_tag), '?xml') & ~isempty(current_tag)
      error('xmltools:parse_xml', 'malformed xml string (current [%s])', current_tag);
    else
      fprintf('end parsing at level %d\n',idx);
      eot = 1;
      return
    end
  end
  %>
  
  if isempty(f_end)
    f_end = length(str)
  else
    f_end = f_end(1);
  end
  if isempty(f_beg)
    f_beg = length(str)
  else
    f_beg = f_beg(1);
  end
  
  if f_end <= f_beg
    %< je rencontre une fermeture
    new_tag = str((f_end+2):end);
    str_t   = str(1:f_end-1);
    f_end = strfind(new_tag,'>');
    if isempty(f_end)
      error('xmltools:parse_xml', 'malformed xml string : never ending tag [%s] encountered', current_tag);
    end
    f_end = f_end(1);
    str     = new_tag(f_end+1:end); % reste
    new_tag = new_tag(1:f_end-1);
    if ~strcmp((new_tag), (current_tag))
      error('xmltools:parse_xml', 'malformed xml string : [%s] not properly closed (closing [%s] encountered)', current_tag, new_tag);
    end
    if Verbose
       fprintf('%sclose [%s]\n', repmat(' ', 2*(idx-1),1), current_tag);
    end
    z.tag     = (current_tag);
    z.attribs = parse_attribs(attribs);
    z.value   = udeblank(deblank(sprintf('%s %s',current_value, str_t)));
    eot       = 1;
    %>
  else
    %< je rencontre une ouverture
    % je vais appeler le m�me code sur ce qu'il y a apr�s moi
    current_value = sprintf('%s %s', current_value, str(1:f_beg-1));
    new_tag   = str(f_beg+1:end);
    f_end = strfind(new_tag,'>');
    if isempty(f_end)
      error('xmltools:parse_xml', 'malformed xml string : never ending tag encountered');
    end
    f_end   = f_end(1);
    str_t   = new_tag(f_end+1:end);
    new_tag = new_tag(1:f_end-1);
    if (new_tag(end) == '/')|(new_tag(end) == '?')
      %< Self closing tag
      % Je met (temporairement!) eot � 1, cela me permet de passer quelques lignes
      % de code tranquilement
      eot = 1;
      %>
    end
    %< Attributs
    f_beg   = strfind(new_tag, ' ');
    if isempty(f_beg)
      new_attribs = '';
      if eot
	new_tag = new_tag(1:end-1);
      end
    else
      new_attribs = new_tag(f_beg+1:end);
      if eot
	new_attribs = new_attribs(1:end-1);
      end
      new_tag     = new_tag(1:f_beg-1);
    end
    %>
    if Verbose
        fprintf('%sopen  [%s]\n', repmat(' ', 2*idx,1), new_tag);
    end
    if eot
      %< If self-colsing tag
      if Verbose
          fprintf('%sclose [%s]\n', repmat(' ', 2*idx,1), new_tag);
      end
      new_attribs = parse_attribs( new_attribs);
      if isfield(z, next)
        nxt = getfield(z, next);
        nxt(end+1) = struct( 'tag', new_tag, 'attribs', new_attribs, 'value', '', next, []);
        z   = setfield(z, next, nxt);
	%z.(next)(end+1) = struct( 'tag', new_tag, 'attribs', new_attribs, 'value', '', next, []);
      else
        z = setfield(z, next, struct( 'tag', new_tag, 'attribs', new_attribs, 'value', '', next, []) );
	%z.(next) = struct( 'tag', new_tag, 'attribs', new_attribs, 'value', '', next, []);
      end
      str = str_t;
      eot = 0;
      %>
    else
      %< Appel du m�me code sur la suite

      % et stockage du resultat dans mes children.
      % Le code met aussi � jour le string courant |str|,
      % il en enl�ve la partie correspondant au string que je viens de trouver.
      [t,str] = parse_xml(str_t, new_tag, '', new_attribs, 1+idx);
      if isfield(t, next)
	nx = getfield( t, next);
        %nx = t.(next);
      else
	nx = [];
      end
      if isfield(z, next)
        nxt = getfield(z, next);
        nxt(end+1) = struct( 'tag', t.tag, 'attribs', t.attribs, 'value', t.value, next, nx);
        z   = setfield(z, next, nxt);
	%z.(next)(end+1) = struct( 'tag', t.tag, 'attribs', t.attribs, 'value', t.value, next, nx);
      else
	z = setfield(z, next, struct( 'tag', t.tag, 'attribs', t.attribs, 'value', t.value, next, nx));
	%z.(next) = struct( 'tag', t.tag, 'attribs', t.attribs, 'value', t.value, next, nx);
      end

      %>
    end
  end
  %>
end
%>

%< Parse attribs
function z =  parse_attribs( a)
if isempty(a)
  z = struct( 'name', '', 'value', '');
  return
end
b = tokens(a, ' ');
j = 1;
   
for i=1:length(b)
  if ~isempty(b{i})
    t = tokens(b{i}, '=');
    if length(t)==2
      u = t{2};
      if u(1)=='"'
	u = u(2:end);
      end
      if u(end)=='"'
	u = u(1:end-1);
      end
      z(j) = struct( 'name', (t{1}), 'value', u);
    else
        %here is the possible problem: if there is space between name and
        %'=' and value this will be counted 3 times as different names and
        %empty value
      z(j) = struct( 'name', (a), 'value', '');
    end
    j = j +1;
  end
end
%>


%<* Ecriture d'une structure xml
function z = write_xml(fid, xml_struct, idx)

next = 'child';

if nargin < 3
  idx = 0;
end

margin = repmat(' ',idx,1);

closed_tag = 1;
%< Ouverture du tag
if isfield(xml_struct, 'tag')
  closed_tag = 0;
  fprintf(fid, '%s<%s', margin, xml_struct.tag);
  %< Ecriture des attributs
  if ~isfield(xml_struct, 'attribs')
    error('xmltools:write_xml', 'malformed MATLAB xml structure : tag without attribs');
  end
  for i=1:length(xml_struct.attribs)
    if ~isempty(xml_struct.attribs(i).name)
        if xml_struct.tag(1) == '?'
            fprintf(fid, ' %s=%s', xml_struct.attribs(i).name, xml_struct.attribs(i).value);
        else
          fprintf(fid, ' %s="%s"', xml_struct.attribs(i).name, xml_struct.attribs(i).value);
        end
    end
  end
  %>
  
  %< Gestion des Auto closed tags
  % Si le tag n'est pas auto ferm�, alors |closed_tag| est � z�ro
  if ~isfield(xml_struct, next)
    error('xmltools:write_xml', 'malformed MATLAB xml structure : tag without %s', next);
  end
  if ~isfield(xml_struct, 'value')
    error('xmltools:write_xml', 'malformed MATLAB xml structure : tag without value');
  end
  if xml_struct.tag(1) == '?'
    fprintf(fid, '?>\n');
    closed_tag = 1;
  elseif isempty(getfield(xml_struct, next)) & isempty(xml_struct.value)
  %elseif isempty(xml_struct.(next)) & isempty(xml_struct.value)
    fprintf(fid, '/>\n');
    closed_tag = 1;
  elseif ~isempty(xml_struct.value)
      fprintf(fid, '>');
  else
      fprintf(fid, '>\n');
  end
  %>
end
%>

%< Ecriture de la value
if isfield(xml_struct, 'value')
  if ~isempty(xml_struct.value)
    fprintf(fid, '%s',  xml_struct.value);
  end
end
%>

%< Ecriture des enfants
if ~isfield(xml_struct, next)
  error('xmltools:write_xml', 'malformed MATLAB xml structure : tag without %s', next);
end
those_children = getfield(xml_struct, next);
%those_children = xml_struct.(next);

for i=1:length(those_children)
  write_xml(fid, those_children(i), idx+1);
end
%>

%< Fermeture du tag
if ~closed_tag
    if ~isempty(xml_struct.value)
        fprintf(fid, '</%s>\n',  xml_struct.tag);
    else
      fprintf(fid, '%s</%s>\n',  margin,xml_struct.tag);
    end
end
%>
%>*


%<* get childs with a specific tag name
function z = get_childs(z, next, tag_name);
u = getfield(z, next);
zo = [];
for i=1:length(u)
  v = u(i);
  if strcmp((v.tag), (tag_name))
    if isempty(zo)
      zo.anext= v;
    else
      zo.anext(end+1) = v;
    end
  end
end
if ~isstruct( zo)
  if isfield(z, 'tag')
    tn = z.tag;
  else
    tn = 'root?';
  end
  error('XMLTOOLS:GET-TEG', 'problem in finding tag <%s> under one <%s>', tag_name, tn);
end
z = [ zo.anext ];
%>*

%< udeblank
function s = udeblank(str)
s = deblank(str(end:-1:1));
s = s(end:-1:1);
if length(s)==0
  s = '';
end
%>

%< emptystruct
function z = emptystruct(next)
z = struct( 'tag', [], 'value', [], 'attribs', [], next, []);
%>

%< Tokens
function l = tokens(str,del)
l={} ; 
% Boucle sur les tokens.
del = sprintf(del) ;

space_pos = strfind(str,del);
eq_pos = strfind(str,'=');
index2squash = [];
for k=1:length(eq_pos)
    if sum(ismember(eq_pos(k)+[-1 1], space_pos))==2
        index2squash = [index2squash eq_pos(k)+[-1 1]];
    end
end
str(index2squash)='';

while ~isempty(str)
  [tok,str] = strtok(str,del) ;
  l{end+1} = tok ;
end

%fixing possible spaces btw '=' and name/value
% if length(l)==3 & strcmp(l{2},'=')
%     keyboard
% end

%>