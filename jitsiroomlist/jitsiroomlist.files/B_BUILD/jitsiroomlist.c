// jitsiroomlist 2020-06-10 19:00 CEST
#define VERSION "0.4"
//
// This program filters jicofo log and prints a list of existing
// conference rooms. Inspired by an idea of Joost Snellink.
// (c) 2020 Markus B. Weber
//
// compile: gcc jitsiroomlist.c -o jitsiroomlist
//
const char* helptext=
"\njitsiroomlist " VERSION "\n"
"\n"
"This program filters jicofo log and writes a list of existing\n"
"conference rooms. Inspired by an idea of Joost Snellink.\n"
"(c) 2020 Markus B. Weber\n"
"\n"
"usage example:\n"
"jitsiroomlist /usr/share/jitsi-meet/static/status/rooms.txt\n"
"              /usr/share/jitsi-meet/static/status/roomlog.txt\n"
"              </var/log/jitsi/jicofo.log\n"
"              >>/var/log/jitsi/jicofon.log\n"
"\n"
"It is recommended to replace the file jicofo.log by a named pipe.\n"
"This program comes with NO WARRANTY, to the extent permitted by law.\n"
"\n";
//#define ROOMLISTLOGFILETIMESTAMP  // uncomment to use own timestamp
//
// This program is free software; you can redistribute it and/or
// modify it under the terms of the GNU General Public License
// version 2 or later as published by the Free Software Foundation.
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// You should have received a copy of this license along
// with this program; if not, see http://www.gnu.org/licenses/.
//
// Other licenses are available on request; please ask the author.
//
#if 0  // jicofo.log examples (snippets) (XXXX == server domain)

    user USER creates room ROOM (line with room name):
    (note that this logline ist followed directly by the line with the user name;)
Jicofo 2020-04-23 13:05:47.250 INFO: [52] org.jitsi.jicofo.xmpp.FocusComponent.handleConferenceIq().401 Focus request for room: ROOM@conference.XXXX

    user USER creates room ROOM (line with user name):
    (there are two different "AbstractAuthAuthority.log" lines;
     take the line with the phrase "@guest." in it;
     and please note that in this line the room name ROOM might
     not be present; that is the reason why both, this line and the
     previous line need to be examined;)
Jicofo 2020-04-23 13:05:47.251 INFO: [52] org.jitsi.jicofo.auth.AbstractAuthAuthority.log() Authenticated jid: vuvrubpobmncwjiv@guest.XXXX/lAhvizlT with session: AuthSession[ID=USER@XXXX, JID=vuvrubpobmncwjiv@guest.XXXX/lAhvizlT, SID=3bfc41b0-9884-4046-9de8-45bea1711e39, MUID=20a3c04628d6a15c17a3803f74c93697, LIFE_TM_SEC=382, R=ROOM@conference.XXXX]@1437959680

    a user enters the room ROOM:
Jicofo 2020-04-22 14:53:50.118 org.jitsi.jicofo.JitsiMeetConferenceImpl.log() Member ROOM@conference.XXXX/e29c3299 joined.

    a user leaves the room ROOM:
Jicofo 2020-04-22 14:55:10.421 org.jitsi.jicofo.JitsiMeetConferenceImpl.log() Member ROOM@conference.XXXX/e29c3299 is leaving

    the room ROOM has been deleted:
Jicofo 2020-04-22 14:55:16.839 org.jitsi.jicofo.FocusManager.log() Disposed conference for room: ROOM@conference.XXXX conference count: 2

    the room ROOM is now being recorded
Jicofo 2020-05-28 11:45:54.063 INFORMACIÓN: [2036] org.jitsi.jicofo.recording.jibri.JibriRecorder.log() Publishing new jibri-recording-status: <jibri-recording-status xmlns='http://jitsi.org/protocol/jibri' status='on' session_id='xxx' initiator='ROOM@conference.XXXX/yyy' recording_mode='file'/> in: ROOM@conference.XXXX

    the room ROOM is no longer being recorded 
Jicofo 2020-05-28 11:47:21.365 INFORMACIÓN: [2040] org.jitsi.jicofo.recording.jibri.JibriRecorder.log() Publishing new jibri-recording-status: <jibri-recording-status xmlns='http://jitsi.org/protocol/jibri' status='off' session_id='xxx' initiator='ROOM@conference.XXXX/yyy' recording_mode='file'/> in: ROOM@conference.XXXX

#endif
#include <inttypes.h>
#include <ctype.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <sys/time.h>
#include <time.h>
typedef enum {false= 0,true= 1} bool;
#define NOE(x) (sizeof(x)/sizeof(x[0]))  // number of elements

static inline char *strmcpy(char *dest, const char *src, size_t maxlen) {
  // similar to strcpy(), this procedure copies a character string;
  // here, the length is cared about, i.e. the target string will
  // be limited in case it is too long;
  // src[]: source string which is to be copied;
  // maxlen: maximum length of the destination string
  //         (including terminator null);
  // return:
  // dest[]: destination string of the copy; this is the
  //         function's return value too;
  char* d;

  if(maxlen==0)
return dest;
  d= dest;
  while(--maxlen>0 && *src!=0)
    *d++= *src++;
  *d= 0;
  return dest;
  }  // end   strmcpy()
#define strMcpy(d,s) strmcpy((d),(s),sizeof(d))

#ifdef ROOMLISTLOGFILETIMESTAMP
static void timestamp(char* str) {
  // write a timestamp (date and time of day);
  // output:
  // str[]: string which will receive the timestamp;
  //        format: "2020-12-31_23:59:59" (length 19 chars);
  //        sizeof(str) must be at least 20 bytes;
  struct timeval tv;
  struct tm* tim;

  gettimeofday(&tv,NULL);
  tim = localtime(&tv.tv_sec);
  sprintf(str,"%04i-%02i-%02i_%02i.%02i.%02i",
    tim->tm_year+1900,tim->tm_mon+1,tim->tm_mday,
    tim->tm_hour,tim->tm_min,tim->tm_sec);
  }  // timestamp()
#endif

static const char* global_roomlistfile= NULL;
  // destination path for the automatically updated room list;
static const char* global_roomlistlogfile= NULL;
  // destination path for the room list logfile;

static void roomlist(int action,const char* start,
    const char* name,const char* owner) {
  // this procedure stores name and content information of each room;
  // start[]: time of log entry; format: "hh:mm:ss";
  //          does not need to be zero-terminated;
  // action: 0: enter a new owner for a room;
  //            if there is no room with this name on list,
  //            create a new entry;
  //         1: increment the number of conference members;
  //            if there is no room with this name on list,
  //            create a new entry;
  //        -1: decrement the number of conference members;
  //        -2: delete room from list;
  //        -8: set recording flags;
  //        -9: remove currently-recording flag;
  // name[]: name of this room; may be NULL for action==9;
  // owner[]: owner of this room; may be NULL;
  // note that this is a lazily programmed procedure; it uses an array
  // and not a list of chained records; however this should be fast
  // enough for this purpose;
  #define roomM 200  // max number of elements in list
  typedef struct room_struct {
    char start[20];
    char name[76];
    char owner[20];
    int32_t memb,maxmemb;
    int32_t flags;  // bit 0: now being recorded;
                    // bit 1: has at least being recorded once;
    } room_t;
  static room_t room[roomM];
  static int roomn= 0;  // number of elements in list
  static room_t* roompe= room;  // address of first free record
  room_t* rp;  // address of record of currently modified room

  // search room list for a room with the given name
  rp= roompe;
  while(--rp>=room) {
    if(strcmp(name,rp->name)==0)
  break;
    }
  if(!(rp>=room)) {  // there is no room with this name
    // create a new entry for this room
    if(roomn<roomM) {  // still enough space in list
      rp= roompe;
      roomn++; roompe++;
      }
    else
      rp= room;  // overwrite oldest entry
    rp->start[0]= 0;
    strMcpy(rp->name,name);
    rp->owner[0]= 0;
    rp->memb= rp->maxmemb= rp->flags= 0;
    }  // there is no room with this name
  if(rp->start[0]==0) {
    #ifdef ROOMLISTLOGFILETIMESTAMP
      timestamp(rp->start);
    #else
      if(memcmp(start,"Jicofo ",7)==0) start+= 7;
      strMcpy(rp->start,start);
      rp->start[10]= '_';
    #endif
    }
  if(owner!=NULL)
    strMcpy(rp->owner,owner);
  if(action>0) {  // increment number of room members
    rp->memb++;
    if(rp->memb>rp->maxmemb)
      rp->maxmemb= rp->memb;
    }
  else if(action==-1)  // decrement number of room members
    rp->memb--;
  else if(action==-2) {  // delete the room
    if(global_roomlistlogfile!=NULL) {  // room list log required
      FILE* fi;
      char ts[20];

      fi= fopen(global_roomlistlogfile,"a");
      if(fi!=NULL) {  // successfully opened
        #ifdef ROOMLISTLOGFILETIMESTAMP
          timestamp(ts);
        #else
          if(memcmp(start,"Jicofo ",7)==0) start+= 7;
          strMcpy(ts,start);
          ts[10]= '_';
        #endif
        fprintf(fi,"%-19s %-19s %.400s [%.400s] %d%s\n",
          ts,rp->start,
          rp->name,
          rp->owner!=NULL?rp->owner:"",
          rp->maxmemb,
          rp->flags&2? " R": "");
        fclose(fi);
        }  // successfully opened
      }  // room list log required
    roomn--; roompe--;
    if(rp<roompe)  // index was not last in list
      // move all subsequent elements
      memmove(rp,rp+1,((char*)roompe)-((char*)rp));
    }  // delete the room
  else if(action==-8) {  // set recording flags
    rp->flags|= 3;
    }
  else if(action==-9) {  // clear currently-recording flag
    rp->flags&= ~1;
    }
  /* reprint room list */ {
    FILE* fi; int i,membn;
    fi= fopen(global_roomlistfile,"w");
    if(fi!=NULL) {  // successfully opened
      membn= 0;  // counter for total number of members
      // print headline
      fprintf(fi,"Jitsi Room list (creation_time room_name "
        "[owner] member_count)\n\n");
      // print one line for each room
      rp= room;
      i= roomn;
      while(--i>=0) {  // for each room in list
        fprintf(fi,"%.19s %.400s [%.400s] %d%s\n",
          rp->start,
          rp->name,
          rp->owner!=NULL?rp->owner:"",
          rp->memb,
          (rp->flags&3)==3? " R": rp->flags&2? " r": "");
        membn+= rp->memb;
        rp++;
        }  // for each room in list
      // print totals
      fprintf(fi,"\n(rooms: %i, members: %i)\n",roomn,membn);
      fclose(fi);
      }  // successfully opened
    }  // reprint room list
  }  // roomlist()

static inline bool strfind(char* str,
    const char* prestr1,const char* prestr2,
    const char* startstr,const char endchar,
    char** startp,char** endp) {
  // search the string str[] for the phrase startstr[] and
  // a following endchar;
  // if found, terminate the section between these two with
  // a zero character and return both, the start position of this
  // section and the position after the terminator;
  // if prestr1[] is given, ensure that it is present left of startstr[];
  // if prestr2[] is given, ensure that it is present between prestr1[]
  // and startstr[];
  // str: start position of the string search;
  // prestr1[]: phrase which is expected to precede startstr[];
  //            ==NULL: no preceding phrase expected;
  // prestr2[]: phrase which is expected to be between prestr1[] and
  //            startstr[];
  //            ==NULL: no second preceding phrase expected;
  // startstr[]: phrase which precedes the requested section;
  // endchar: character which terminates the requested section;
  // return: requested section has been found;
  // *startp: if section found: position of the found section;
  //          if not found: unchanged;
  // *endp:   if section found && endp!=NULL:
  //            position after the section terminator;
  //          if not found: unchanged;
  //
  char* stre;

  // test for prestr1[] and prestr2[], if appl.
  if(prestr1!=NULL) {  // prestr1[] required
    str= strstr(str,prestr1);
    if(str==NULL)
return false;
    str+= strlen(prestr1);  // jump over prestr1[]
    if(prestr2!=NULL) {  // prestr2[] required
      str= strstr(str,prestr2);
      if(str==NULL)
return false;
      str+= strlen(prestr2);  // jump over prestr2[]
      }  // prestr2[] required
    }  // prestr1[] required

  // search for startstr[]
  str= strstr(str,startstr);
  if(str==NULL)
return false;
  str+= strlen(startstr);  // jump over startstr[]

  // search for endchar
  stre= strchr(str,endchar);
  if(stre==NULL)
return false;
  *stre++= 0;  // terminate section and jump over termination character

  // return result
  *startp= str;
  if(endp!=NULL)
    *endp= stre;
  return true;
  }  // strfind()



int main(int argc,const char** argv) {
  #define lineM 2000
  char line[lineM];  // input line
  char* lpe;  // pointer to end of line[];
  char* startp,*endp;  // start and end of a parameter in line[];
  char lastroomname[200];  // temporarily store the name of a focussed
    // room because the owner's name might follow in the next log line
  int lastroomnamevalid;
    // number of following log lines this room name will be accepted
    // including the current line);

  if(argc<2 || argc>3) {
    printf("%s",helptext);  // print help text
      // (took "%s", to prevent oversensitive compiler reactions)
  return EXIT_FAILURE;
    }
  global_roomlistfile= argv[1];
  if(argc==3)
    global_roomlistlogfile= argv[2];
  setlinebuf(stdout);
  lastroomname[0]= 0;
  lastroomnamevalid= 0;
  for(;;) {  // for each line in standard input
    if(fgets(line,sizeof(line),stdin)==NULL)
  break;
    lpe= strchr(line,0);
    while(lpe>line && lpe[-1]<32) *--lpe= 0;
      // remove trailing control bytes
    puts(line);
    if(lpe-line<40)  // line too short
  continue;
    if(lastroomnamevalid>0) lastroomnamevalid--;

    if  // a room name has been detected
        (strfind(line,NULL,NULL,
        "org.jitsi.jicofo.xmpp.FocusComponent."
        "handleConferenceIq().401 Focus request for room: ",
        '@',&startp,NULL)) {
      strMcpy(lastroomname,startp);  // temporarily store this room name
      lastroomnamevalid= 1+2;
      }  // a room name has been detected

    else if  // a room has been created by a user
        (strfind(line,
        "org.jitsi.jicofo.auth."
        "AbstractAuthAuthority.log() Authenticated jid: ",
        "@guest.",
        " with session: AuthSession[ID=",
        '@',&startp,&endp)) {
      if(lastroomnamevalid>0) {
          // there was a room name in one of the last log lines
        roomlist(0,line,lastroomname,startp);  // enter into room list
        lastroomnamevalid= 0;
          // room name of last log lines is no longer valid
        }  // there was a room name in one of the last log lines
      }  // a room has been created by a user

    else if  // a room has been entered or left by a user
        (strfind(line,NULL,NULL,
        "org.jitsi.jicofo.JitsiMeetConferenceImpl.log() Member ",
        '@',&startp,NULL)) {
      if(strcmp(lpe-8," joined.")==0)
        roomlist(1,line,startp,NULL);  // increment number in room list
      else if(strcmp(lpe-11," is leaving")==0)
        roomlist(-1,line,startp,NULL);  // decrement number in room list
      }  // a room has been entered or left by a user

    else if  // a room has been deleted
        (strfind(line,NULL,NULL,
        "org.jitsi.jicofo.FocusManager.log() "
        "Disposed conference for room: ",
        '@',&startp,NULL)) {
      roomlist(-2,line,startp,NULL);  // remove from room list
      }  //  a room has been deleted

    else if  // recording of a room has been started
        (strfind(line,
        "org.jitsi.jicofo.recording.jibri.JibriRecorder.log() "
        "Publishing new jibri-recording-status:",
         " status=\'on\' ",
        "initiator=\'",
        '@',&startp,NULL)) {
      roomlist(-8,line,startp,NULL);  // log start of recording
      }  // recording of a room has been started

    else if  // recording of a room has been terminated
        (strfind(line,
        "org.jitsi.jicofo.recording.jibri.JibriRecorder.log() "
        "Publishing new jibri-recording-status:",
         " status=\'off\' ",
        "initiator=\'",
        '@',&startp,NULL)) {
      roomlist(-9,line,startp,NULL);  // log end of recording
      }  // recording of a room has been terminated

    }  // for each line in standard input
  return EXIT_SUCCESS;
  }  // main()

