/*
Copyright (c) 2019 Timur Gafarov

Boost Software License - Version 1.0 - August 17th, 2003
Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

module dagon.graphics.entity;

import dlib.core.ownership;
import dlib.container.array;
import dlib.math.vector;
import dlib.math.matrix;
import dlib.math.quaternion;
import dlib.math.transformation;

import dagon.core.bindings;
import dagon.core.event;
import dagon.core.time;
import dagon.graphics.updateable;
import dagon.graphics.drawable;
import dagon.graphics.material;

class EntityManager: Owner
{
    DynamicArray!Entity entities;
    
    this(Owner owner)
    {
        super(owner);
    }
    
    void addEntity(Entity e)
    {
        entities.append(e);
    }
    
    ~this()
    {
        entities.free();
    }
}

class Entity: Owner, Updateable
{   
    int layer = 0;
    bool visible = true;
    bool castShadow = true;
    bool solid = false;
    bool dynamic = true;

    EntityManager manager;
    
    Entity parent = null;
    DynamicArray!Entity children;

    DynamicArray!EntityComponent components;
    
    Drawable drawable;
    Material material;
    
    Vector3f position;
    Quaternionf rotation;
    Vector3f scaling;
    
    Matrix4x4f transformation;
    Matrix4x4f invTransformation;
    
    Matrix4x4f absoluteTransformation;
    Matrix4x4f invAbsoluteTransformation;
    
    Matrix4x4f prevTransformation;
    Matrix4x4f prevAbsoluteTransformation;
    
    this(EntityManager manager, int layer = 0)
    {
        super(manager);
        this.manager = manager;
        manager.addEntity(this);
        
        this.layer = layer;
        
        position = Vector3f(0, 0, 0);
        rotation = Quaternionf.identity;
        scaling = Vector3f(1, 1, 1);
        
        transformation = Matrix4x4f.identity;
        invTransformation = Matrix4x4f.identity;
        
        absoluteTransformation = Matrix4x4f.identity;
        invAbsoluteTransformation = Matrix4x4f.identity;
        
        prevTransformation = Matrix4x4f.identity;
        prevAbsoluteTransformation = Matrix4x4f.identity;
    }
    
    void setParent(Entity e)
    {
        if (parent)
            parent.removeChild(this);
            
        parent = e;
        parent.addChild(e);
    }
    
    void addChild(Entity e)
    {
        children.append(e);
    }
    
    void removeChild(Entity e)
    {
        children.removeFirst(e);
    }
    
    void addComponent(EntityComponent ec)
    {
        components.append(ec);
    }
    
    void removeComponent(EntityComponent ec)
    {
        components.removeFirst(ec);
    }
    
    void updateTransformation()
    {
        prevTransformation = transformation;
        
        transformation =
            translationMatrix(position) *
            rotation.toMatrix4x4 *
            scaleMatrix(scaling);
            
        invTransformation = transformation.inverse;
        
        if (parent)
        {
            absoluteTransformation = parent.absoluteTransformation * transformation;
            invAbsoluteTransformation = invTransformation * parent.invAbsoluteTransformation;
            prevAbsoluteTransformation = parent.prevAbsoluteTransformation * prevTransformation;
        }
        else
        {
            absoluteTransformation = transformation;
            invAbsoluteTransformation = invTransformation;
            prevAbsoluteTransformation = prevTransformation;
        }
    }
    
    void update(Time t)
    {
        updateTransformation();
        
        foreach(c; components)
        {
            c.update(t);
        }
    }
    
    void release()
    {
        if (parent)
            parent.removeChild(this);
            
        for (size_t i = 0; i < children.data.length; i++)
            children.data[i].parent = null;
            
        children.free();
        components.free();
    }
    
    ~this()
    {
        release();
    }
    
    void processEvents()
    {
        foreach(c; components)
        {
            c.processEvents();
        }
    }
}

class EntityComponent: EventListener, Updateable, Drawable
{
    Entity entity;

    this(EventManager em, Entity e)
    {
        super(em, e);
        entity = e;
        entity.addComponent(this);
    }
    
    // Override me
    void update(Time t)
    {
    }
    
    // Override me
    void render(State* state)
    {
    }
}

interface EntityGroup
{
    int opApply(scope int delegate(Entity) dg);
}
