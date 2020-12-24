function index = fastsearch (array, wert, bias)

% Find the value (wert) in the in ascending order sorted array (array) with 
% fastsearch-algorithm
% Input
% array:    array to search in
% wert:     element to search for
% bias:     0: search exact the element
%           +1: search the element or the next greater
%           -1: search the element or the next smaller
% Output
% index:    index of the element in array;
%           -1 if not found

% Die Funktion findet das Element im aufsteigend soriterten array nach dem
% fastsearch-Algorithmus 
% Input
% array:    array, wo gesucht wird
% wert:     Element, nach dem gesucht wird
% bias:     0:  Es wird genau nach dem Element gesucht
%           +1: ..nach dem Element oder nach dem nächst höchsten gesucht
%           -1: ..nach dem Element oder nach dem nächst kleinsten gesucht
%
% Output
% index:    Index des gesuchten Elementes im array;
%           -1, falls nicht gefunden wird.

%           Wenn das Element nicht im array ist und bias==0, kommt es zu
%           einer Fehlermeldung "Maximum recursion limit of 500 reached."

% Valentin Kuklin, v.kuklin@lpa.uni-saarland.de
% 18.10.2007
% 09.12.2008

if nargin<3
    error('Need five inputs: Search array, search value, bias')
end

if bias~=-1 && bias~=0 && bias ~=1
    error('Bias should be one of {-1 0 1}')
end

% Check if wert is inside of array. If not, check if the smallest or the
% greatest number is searched
if wert<array(1)
    if bias==1
        index=1;
        return;
    else
        index=-1;
        return;
    end
end
if wert>array(end)
    if bias == -1
        index = length(array);
        return;
    else
        index = -1;
        return;
    end
end
index = fastsearch_indeed(array,1,length(array),wert,bias); 
return;


function index = fastsearch_indeed(array, von, bis, wert, bias)

% Search algorithm

% von:      lower border of the search region, should be set to 1.
% bis:      higher border of the search region, should be set to 
%           length(array). These variables cannot be initialize within the
%           function because of the recursion. 

% von:      untere Grenze der Suche, beim Aufruf der Funktion muss 1
%           übergeben werden. Die rekursive Arbeitsweise der Funktion
%           erlaubt nicht eine interne Initializierung
% bis:      obere Grenze der Suche, beim Aufruf der Funktion muss 
%           length(array) übergeben werden. 


if (von<=bis)
    m1 = floor(((von+bis)/2));
    % if array(bis)==array(von) it would be devide by zero
    % take care! If array(bis) and array(bis) and wert are veeery closed to
    % each other, it could evoke numerical erros
    if (array(bis)~=array(von))
        m2 = von + floor((bis-von)*(wert-array(von))/...
                                                (array(bis)-array(von)));
    else
        m2=m1;
    end
    % m1 should be the greatest number
    if m1<m2
       a = m1;
       m1=m2;
       m2=a;
    end
    % Conditions for search - the next greatest, smallest
    % Folgende Fälle müssen betrachtet werden: 
    % (m_n)-1..wert..m_n oder m_n..wert..(m_n+1), n={1 2}. Für die
    % unterschiedlichen bias müssen entsprechnde Indizes zurückgegeben
    % werden
    return_m1 = ((wert<array(m1))&&(wert>array(m1-1))&&(bias==1))||...
                ((wert<array(m1+1))&&(wert>array(m1))&&(bias==-1))||...
                (wert==array(m1));
    if return_m1
        index=m1;
        return
    end
    return_m2 = ((wert<array(m2))&&(wert>array(m2-1))&&(bias==1))||...
                ((wert<array(m2+1))&&(wert>array(m2))&&(bias==-1))||...
                (wert==array(m2));
    if return_m2
        index=m2;
        return
    end
    if (wert<array(m1))&&(wert>array(m1-1))&&(bias==-1)
        index=m1-1;
        return
    end
    if (wert<array(m1+1))&&(wert>array(m1))&&(bias==1)
        index=m1+1;
        return
    end
    
    if (wert<array(m2))&&(wert>array(m2-1))&&(bias==-1)
        index=m2-1;
        return
    end
    if (wert<array(m2+1))&&(wert>array(m2))&&(bias==1)
        index=m2+1;
        return
    end

    if wert<array(m1)
        index=fastsearch_indeed(array,von,m1-1,wert,bias);
        return;
    else
        index=fastsearch_indeed(array,m2+1,bis,wert,bias);
        return;
    end
end
index=-1;
return;

