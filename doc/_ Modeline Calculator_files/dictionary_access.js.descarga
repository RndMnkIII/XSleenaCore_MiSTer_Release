/***************************************************************************
 *   Copyright (C) 2006, Paul Lutus                                        *
 *                                                                         *
 *   This program is free software; you can redistribute it and/or modify  *
 *   it under the terms of the GNU General Public License as published by  *
 *   the Free Software Foundation; either version 2 of the License, or     *
 *   (at your option) any later version.                                   *
 *                                                                         *
 *   This program is distributed in the hope that it will be useful,       *
 *   but WITHOUT ANY WARRANTY; without even the implied warranty of        *
 *   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the         *
 *   GNU General Public License for more details.                          *
 *                                                                         *
 *   You should have received a copy of the GNU General Public License     *
 *   along with this program; if not, write to the                         *
 *   Free Software Foundation, Inc.,                                       *
 *   59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.             *
 ***************************************************************************/

// I had a different way to do this, but I realized
// this content creates a much nicer outcome, and I didn't
// want to re-edit al my pages to change the JavaScript URL
// so ...

// function to add an event listener

addEvent(document,"dblclick", dictionary);

function addEvent(o,e,f) {
  if (o.addEventListener) {
    o.addEventListener(e,f,false);
    return true;
  }
  else if (o.attachEvent) {
    return o.attachEvent("on"+e,f);
  }
  else {
    return false;
  }
}

function dictionary(e) {
  // accept only a double-click with no modifiers
  if(e.ctrlKey == true || e.shiftKey == true || e.altKey == true) return;
  if (navigator.appName != 'Microsoft Internet Explorer') {
    var str = "" + window.getSelection();
    if(str > '' && str.length > 1) {
      dictionary_access(str);
    }
  }
  else {
    var t = document.selection;
    var ts = t.createRange();
    if(t.type == 'Text' && ts.text > '' && t.text.length > 1) {
      document.selection.empty();
      dictionary_access(ts.text);
    }
  }
}

function dictionary_access(str) {
  // remove problem characters
  str = str.replace(/[!.:?,;\"]/g, '');
  // trim leading and trailing whitespace
  str = str.replace(/^\s*(\S*?)\s*$/g,"$1");
  // if (str) window.open('http://www.thefreedictionary.com/'+encodeURIComponent(str), 'dict', 'width=700,height=500,resizable=1,menubar=1,scrollbars=1,status=1,titlebar=1,toolbar=1,location=1,personalbar=1');
  if (str) window.open('http://www.merriam-webster.com/dictionary/'+encodeURIComponent(str), 'Definitions', 'width=700,height=500,resizable=1,menubar=1,scrollbars=1,status=1,titlebar=1,toolbar=1,location=1,personalbar=1');
}



