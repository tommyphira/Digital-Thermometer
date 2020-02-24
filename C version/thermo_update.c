#include "thermo.h"
#include <stdio.h>
#include <string.h>

int thermo_update(){
  temp_t newTemp;
  int newDisplay = 0;

  set_temp_from_ports(&newTemp);
  set_display_from_temp(newTemp,&newDisplay);
  int resultPort = set_temp_from_ports(&newTemp);
  int resultTemp = set_display_from_temp(newTemp,&newDisplay);

  //If the error value 1 is returned from either function then return 1.
  if(resultPort == 1 || resultTemp == 1){
    return 1;
  }

  //Set the display to display the value
  else{
    THERMO_DISPLAY_PORT = newDisplay;
    return 0;
  }
}

int set_temp_from_ports(temp_t *temp){
  //If the value entered is greater than the max then return the error value 1
  if(THERMO_SENSOR_PORT > 64000){
    return 1;
  }
  else{
    temp->is_fahrenheit = THERMO_STATUS_PORT;
    int num = THERMO_SENSOR_PORT%64;

    //If num is 0 then divide by 64 and subtract 500
    if(num == 0){
      num = THERMO_SENSOR_PORT/64;
      num = num - 500;
    }
    //If num is less than 31 then subtract num from the sensor port before dividng and subtracting
    else if(num < 31){
      num = (THERMO_SENSOR_PORT-num)/64;
      num = num - 500;
    }
    //If num is greater than 31 then add num from the sensor port before dividng and subtracting
    else{
      num = (THERMO_SENSOR_PORT+num)/64;
      num = num - 500;
    }

    //Converts to fahrenheit if selected
    if(temp->is_fahrenheit == 1){
      num = (num*90)/50+320;
    }

    //Sets the temperature to the value in celsius or fahrenheit (if selected).
    temp->tenths_degrees = num;
    return 0;
  }
}

int set_display_from_temp(temp_t temp, int *display){
  int temp_tenths;
  int temp_ones;
  int temp_tens;
  int temp_hundreds;

  //Create 4 masks to mask for a number (0-9), a negative, farenheit, or celsius.
  int maskBit[10] = {0b0111111,0b0000110,0b1011011,0b1001111,0b1100110,0b1101101,0b1111101,0b0000111,0b1111111,0b1101111};
  int negativeBit = 0b1000000;
  int farenheitMask = 0b10;
  int celsiusMask = 0b01;
  int tempVal = (int) temp.tenths_degrees;

  //If the value for "is_fahrenheit" is greater than the 1, greater than the max, or less than the main then return the error value 1
  if(temp.is_fahrenheit > 1){
    return 1;
  }
  else if(temp.is_fahrenheit == 1){
    if(temp.tenths_degrees>1220){
      return 1;
    }
    else if(temp.tenths_degrees<-580){
      return 1;
    }
  }

  //This entire if statement applies for a tempVal that is negative and less than or equal to 3 digits
  if(tempVal < 0){
    temp_tenths = 0;
    temp_ones = tempVal%10;

    temp_tens = tempVal/10;
    temp_tens = temp_tens%10;

    temp_hundreds = tempVal/100;
    temp_hundreds = temp_hundreds%10;

    //Check if fahrenheit and applies the fahrenheit mask
    if(temp.is_fahrenheit == 1){
      *display = farenheitMask;
      *display <<= 7;
    }
    //If not fahrenheit then is celsius and applies the celsius mask
    else{
      *display = celsiusMask;
      *display <<= 7;
    }

    //Applies the negative mask
    *display += negativeBit;
    *display <<= 7;

    //Convert from negative to positive so the bitmask for 0-9 may be applied
    if(temp_ones < 0 || temp_tens < 0 || temp_hundreds < 0){
      temp_ones *= -1;
      temp_tens *= -1;
      temp_hundreds *= -1;
    }

    //If statement runs if the leading value is 0
    if(temp_hundreds == 0){
      *display += maskBit[temp_tens];
      *display <<= 7;
      *display += maskBit[temp_ones];
      //Convert back  to positive after applying bitmask
      if(temp_ones > 0 || temp_tens > 0 || temp_hundreds > 0){
        temp_ones *= -1;
        temp_tens *= -1;
        temp_hundreds *= -1;
      }
    }
    else{
      *display += maskBit[temp_hundreds];
      *display <<= 7;
      *display += maskBit[temp_tens];
      *display <<= 7;
      *display += maskBit[temp_ones];
      //Convert back to positive after applying bitmask
      if(temp_ones > 0 || temp_tens > 0 || temp_hundreds > 0){
        temp_ones *= -1;
        temp_tens *= -1;
        temp_hundreds *= -1;
      }
    }
  }

  //This entire else statement applies for a tempVal that is positive
  else{
    //If statment if tempVal has 4 digits
    if(tempVal >= 1000){
      temp_tenths = tempVal%10;

      temp_ones = tempVal/10;
      temp_ones = temp_ones%10;

      temp_tens = tempVal/10;
      temp_tens = temp_tens%10;

      temp_hundreds = tempVal/1000;

      //Check if fahrenheit and applies the fahrenheit mask
      if(temp.is_fahrenheit == 1){
        *display = farenheitMask;
        *display <<= 7;
      }
      //If not fahrenheit then is celsius and applies the celsius mask
      else{
        *display = celsiusMask;
        *display<<= 7;
      }

      //Convert from negative to positive so the bitmask for 0-9 may be applied
      if(temp_tenths < 0 || temp_ones < 0 || temp_tens < 0 || temp_hundreds < 0){
        temp_tenths *= -1;
        temp_ones *= -1;
        temp_tens *= -1;
        temp_hundreds *= -1;
      }

      //If statement runs if the leading value is 0
      if(temp_hundreds == 0){
        *display <<= 7;
        *display += maskBit[temp_tens];
        *display <<= 7;
        *display += maskBit[temp_ones];
        *display <<= 7;
        *display += maskBit[temp_tenths];
        //Convert back to positive after applying bitmask
        if(temp_ones > 0 || temp_tens > 0 || temp_hundreds > 0){
          temp_ones *= -1;
          temp_tens *= -1;
          temp_hundreds *= -1;
        }
      }
      else{
        *display += maskBit[temp_hundreds];
        *display <<= 7;
        *display += maskBit[temp_tens];
        *display <<= 7;
        *display += maskBit[temp_ones];
        *display <<= 7;
        *display += maskBit[temp_tenths];
        //Convert back to positive after applying bitmask
        if(temp_ones > 0 || temp_tens > 0 || temp_hundreds > 0){
          temp_ones *= -1;
          temp_tens *= -1;
          temp_hundreds *= -1;
        }

      }
    }

    //else statement runs if tempVal has 3 digits
    else{
      temp_tenths = 0;
      temp_ones = tempVal%10;

      temp_tens = tempVal/10;
      temp_tens = temp_tens%10;

      temp_hundreds = tempVal/100;
      temp_hundreds = temp_hundreds%10;

      //Check if fahrenheit and applies the fahrenheit mask
      if(temp.is_fahrenheit == 1){
        *display = farenheitMask;
        *display <<= 14;
      }
      //If not fahrenheit then is celsius and applies the celsius mask
      else{
        *display = celsiusMask;
        *display <<= 14;
      }

      //Convert from negative to positive so the bitmask for 0-9 may be applied
      if(temp_ones < 0 || temp_tens < 0 || temp_hundreds < 0){
        temp_ones *= -1;
        temp_tens *= -1;
        temp_hundreds *= -1;
      }

      //If statement runs if the leading value is 0
      if(temp_hundreds == 0){
        *display <<= 7;
        *display += maskBit[temp_tens];
        *display <<= 7;
        *display += maskBit[temp_ones];
        //Convert from negative to positive so the bitmask for 0-9 may be applied
        if(temp_ones > 0 || temp_tens > 0 || temp_hundreds > 0){
          temp_ones *= -1;
          temp_tens *= -1;
          temp_hundreds *= -1;
        }
      }
      else{
        *display += maskBit[temp_hundreds];
        *display <<= 7;
        *display += maskBit[temp_tens];
        *display <<= 7;
        *display += maskBit[temp_ones];
        //Convert back to positive after applying bitmask
        if(temp_ones > 0 || temp_tens > 0 || temp_hundreds > 0){
          temp_ones *= -1;
          temp_tens *= -1;
          temp_hundreds *= -1;
        }
      }
    }
  }
  return 0;
}
