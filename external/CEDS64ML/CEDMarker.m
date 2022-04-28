%{
    Copyright (C) Cambridge Electronic Design Limited 2014
    Author: James Thompson
    Web: www.ced.co.uk email: james@ced.co.uk, softhelp@ced.co.uk

    This file is part of CEDS64ML, a MATLAB interface to the SON64 library.

    CEDS64ML is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    CEDS64ML is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with CEDS64ML.  If not, see <http://www.gnu.org/licenses/>.
%}

classdef CEDMarker < handle
    
    properties (GetAccess = public, SetAccess = private)
        m_Time;
        m_Code1;
        m_Code2;
        m_Code3;
        m_Code4;
    end
    
    methods
        % methods, including the constructor are defined in this bloc
        function obj = CEDMarker(Time, Code1, Code2, Code3, Code4)
            % class constructor
            % set everthing to zero then overwrite it if we have an
            % argument
            obj.m_Time = int64(0);
            obj.m_Code1 = uint8(0);
            obj.m_Code2 = uint8(0);
            obj.m_Code3 = uint8(0);
            obj.m_Code4 = uint8(0);

            if(nargin > 0)
                if (isinteger(Time) && Time > 0)
                    obj.m_Time = int64(Time);
                end
            end
            if(nargin > 1)
                obj.m_Code1 = uint8(Code1(1));
            end
            if(nargin > 2)
                obj.m_Code2 = uint8(Code2(1));
            end
            if(nargin > 3)
                obj.m_Code3 = uint8(Code3(1));
            end
            if(nargin > 4)
                obj.m_Code4 = uint8(Code4(1));
            end
        end
        
        function Code = GetCode(obj, iN)
            switch (iN)
                case 1
                    Code = obj.m_Code1;
                case 2
                    Code = obj.m_Code2;
                case 3
                    Code = obj.m_Code3;
                case 4
                    Code = obj.m_Code4;
                otherwise
                    Code = -22;
            end
        end
        
        function err = SetCode(obj, iN, Code)
            err = 0;
            switch (iN)
                case 1
                    obj.m_Code1 = uint8(Code(1));
                case 2
                    obj.m_Code2 = uint8(Code(1));
                case 3
                    obj.m_Code3 = uint8(Code(1));
                case 4
                    obj.m_Code4 = uint8(Code(1));
                otherwise
                    err = -22;
            end
        end
        
        function Time = GetTime(obj)
            Time = obj.m_Time;
        end
        
        function err = SetTime(obj, Time)
            if (isnumeric(Time) && Time > 0)
                obj.m_Time = int64(Time);
                err = 0;
            else
                err = - 22;
            end
        end
        
        function [ r, c ] = Size(obj)
            r = 0;
            c = 0;
        end
        
        function err = GetData(obj)
            err = -22;
        end
        
        function err = SetData(obj, Data)
            err = -22;
        end
    end
end